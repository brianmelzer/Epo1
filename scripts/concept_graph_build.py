#!/usr/bin/env python3
"""Concept Graph v0 builder — deterministic, stdlib-only.

Reads (all versioned in-repo):
  data/callout_ledger.csv                      the 34 call-outs (concept seeds' ground truth)
  data/concept_graph/concept_seed.csv          29 canonical concepts (authored)
  data/concept_graph/matching_rules.csv        L2 rule patterns + base confidences (authored)
  data/concept_graph/extracts/*.csv            source-system match candidates, pulled by
                                               sql/09_concept_graph_extracts.sql (refreshable)

Writes (data/concept_graph/):
  concept.csv, concept_alias.csv,
  concept_product_bridge.csv, concept_search_bridge.csv, concept_social_bridge.csv,
  concept_retailer_item_bridge.csv, concept_epoca_sku_bridge.csv, concept_outcome_bridge.csv,
  concept_review_queue.csv (proposals appended; human decisions preserved),
  generated/concept_match_audit.csv (full disposition report)

Every bridge row carries: match_type, match_confidence, evidence, caveats,
human_review_needed. Confidence >= AUTO_ACCEPT auto-accepts; everything else
routes to the review queue. Confidences are heuristic bands, not calibrated
probabilities. Curated rows (review_status=approved in the queue) are promoted
to confidence 0.95 on the next build and never re-proposed once rejected.

Usage: python3 scripts/concept_graph_build.py --asof 2026-07-05
"""
import argparse
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CG = os.path.join(ROOT, "data", "concept_graph")
EX = os.path.join(CG, "extracts")
GEN = os.path.join(CG, "generated")

AUTO_ACCEPT = 0.85
MERGE_JACCARD = 0.34


def read(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write(path, rows, fields):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asof", required=True, help="build date stamp, e.g. 2026-07-05")
    asof = ap.parse_args().asof

    seeds = read(os.path.join(CG, "concept_seed.csv"))
    rules = read(os.path.join(CG, "matching_rules.csv"))
    ledger = read(os.path.join(ROOT, "data", "callout_ledger.csv"))
    ledger_by_id = {r["callout_id"]: r for r in ledger}

    # prior human decisions survive rebuilds
    queue_path = os.path.join(CG, "concept_review_queue.csv")
    prior_queue = read(queue_path) if os.path.exists(queue_path) else []
    decided = {
        (q["entity_type"], q["entity_key"], q["proposed_concept_id"]): q
        for q in prior_queue
        if q.get("review_status") in ("approved", "rejected")
    }
    queued = {(q["entity_type"], q["entity_key"], q["proposed_concept_id"])
              for q in prior_queue}

    rule_conf = {
        (r["rule_set"], r["concept_id"]): (float(r["base_confidence"]), r["pattern"], r["notes"])
        for r in rules
    }

    # ---- concept + alias ------------------------------------------------
    concepts, aliases = [], []
    for s in seeds:
        concepts.append({
            "concept_id": s["concept_id"], "canonical_name": s["canonical_name"],
            "level_of_truth": "concept", "category": s["category"],
            "subcategory": s["subcategory"], "brand": s["brand"],
            "attributes": s["attributes"], "price_band": s["price_band"],
            "status": "active", "merged_into": "", "created_from": "ledger",
            "created_at": asof, "updated_at": asof,
        })
        for cid in s["callout_ids"].split(";"):
            led = ledger_by_id.get(cid)
            if led:
                for kw in led["match_keywords"].split("|"):
                    aliases.append({
                        "concept_id": s["concept_id"], "alias_text": kw.strip(),
                        "alias_type": "ledger_keyword", "source": cid, "added_by": "builder",
                    })
        for rs in ("search", "social"):
            got = rule_conf.get((rs, s["concept_id"]))
            if got:
                for alt in got[1].split("|"):
                    aliases.append({
                        "concept_id": s["concept_id"], "alias_text": alt.strip(),
                        "alias_type": f"{rs}_pattern", "source": "matching_rules",
                        "added_by": "builder",
                    })
    seen = set()
    aliases = [a for a in aliases
               if (k := (a["concept_id"], a["alias_text"].lower(), a["alias_type"])) not in seen
               and not seen.add(k)]

    # ---- bridges ---------------------------------------------------------
    audit, queue_new = [], []

    def edge(entity_type, entity_key, cid, match_type, conf, evidence, caveats):
        prior = decided.get((entity_type, entity_key, cid))
        if prior and prior["review_status"] == "rejected":
            disposition, review = "rejected_prior", "false"
        elif prior and prior["review_status"] == "approved":
            conf, match_type = 0.95, "curated_manual"
            disposition, review = "curated", "false"
        elif conf >= AUTO_ACCEPT:
            disposition, review = "auto_accepted", "false"
        else:
            disposition, review = "needs_review", "true"
        row = {
            "concept_id": cid, "match_type": match_type,
            "match_confidence": f"{conf:.2f}", "evidence": evidence,
            "caveats": caveats, "human_review_needed": review,
            "review_status": (prior or {}).get("review_status", ""),
            "reviewer": (prior or {}).get("reviewer", ""), "valid_from": asof,
        }
        audit.append({"entity_type": entity_type, "entity_key": entity_key,
                      "proposed_concept_id": cid, "match_type": match_type,
                      "match_confidence": f"{conf:.2f}", "evidence": evidence,
                      "disposition": disposition, "run_date": asof})
        if disposition == "needs_review" and (entity_type, entity_key, cid) not in queued:
            queue_new.append({"entity_type": entity_type, "entity_key": entity_key,
                              "proposed_concept_id": cid, "match_confidence": f"{conf:.2f}",
                              "reason": evidence, "reviewer": "", "review_status": "",
                              "corrected_concept_id": "", "reviewed_at": "", "proposed_at": asof})
        return None if disposition == "rejected_prior" else row

    prod_rows = []
    for m in read(os.path.join(EX, "product_matches.csv")):
        conf, pat, notes = rule_conf[("product", m["concept_id"])]
        r = edge("amz_product", m["cb_asin"], m["concept_id"], "rule_attribute", conf,
                 f"title ~* '{pat}' in mapped category", notes)
        if r:
            prod_rows.append({**r, "source": "amazon", "cb_product_id": m["cb_product_id"],
                              "asin": m["cb_asin"], "title": m["title"],
                              "best_rank_90d": m["best_rank"], "level_of_truth": "product"})

    search_rows = []
    for m in read(os.path.join(EX, "search_matches.csv")):
        conf, pat, notes = rule_conf[("search", m["concept_id"])]
        r = edge("amz_search_term", m["search_text"], m["concept_id"], "rule_keyword", conf,
                 f"term ~* '{pat}' in last 8 weekly periods", notes)
        if r:
            search_rows.append({**r, "search_text": m["search_text"],
                                "best_rank": m["best_rank"], "n_periods": m["n_periods"],
                                "level_of_truth": "concept"})

    social_rows = []
    for m in read(os.path.join(EX, "social_matches.csv")):
        key = ("social", m["concept_id"])
        conf, pat, notes = rule_conf.get(key, (0.9, "category bucket", "category-level"))
        level = m["level_hint"]
        r = edge("sm_hashtag", m["hashtag"], m["concept_id"], "rule_keyword", conf,
                 f"hashtag ~* '{pat}'", f"{notes}; followed_since={m['followed_since']}")
        if r:
            social_rows.append({**r, "cb_hashtag_id": m["cb_hashtag_id"],
                                "hashtag": m["hashtag"], "followed": m["followed"],
                                "level_of_truth": level})

    retail_rows = []
    for m in read(os.path.join(EX, "walmart_matches.csv")):
        conf, pat, notes = rule_conf[("product", m["concept_id"])]
        conf = round(conf * 0.9, 2)  # cross-retailer title-only penalty
        r = edge("wm_product", m["walmart_id"], m["concept_id"], "rule_attribute", conf,
                 f"walmart title ~* '{pat}'", f"{notes}; title-only cross-retailer")
        if r:
            retail_rows.append({**r, "retailer": "walmart", "cb_product_id": m["cb_product_id"],
                                "retailer_item_id": m["walmart_id"], "title": m["title"],
                                "level_of_truth": "retailer"})

    sku_rows = []
    for m in read(os.path.join(EX, "epoca_asinxref_matches.csv")):
        conf, pat, notes = rule_conf[("product", m["concept_id"])]
        r = edge("epoca_item_code", m["item_code"], m["concept_id"], "exact_key_via_rule", conf,
                 f"asinxref exact ASIN<->item_code ({m['asin']}); concept via title ~* '{pat}'",
                 f"{notes}; ASIN link exact, concept link rule-based")
        if r:
            sku_rows.append({**r, "item_code": m["item_code"], "asin": m["asin"],
                             "amz_title": m["amz_title"], "level_of_truth": "product"})

    outcome_rows = []
    claim = {}
    for s in seeds:
        for cid in s["callout_ids"].split(";"):
            led = ledger_by_id.get(cid, {})
            for kw in led.get("match_keywords", "").split("|"):
                claim.setdefault(kw.strip().lower(), set()).add(s["concept_id"])
    for s in seeds:
        for cid in s["callout_ids"].split(";"):
            led = ledger_by_id.get(cid, {})
            shared = sorted({c for kw in led.get("match_keywords", "").split("|")
                             for c in claim.get(kw.strip().lower(), set())} - {s["concept_id"]})
            outcome_rows.append({
                "concept_id": s["concept_id"], "callout_id": cid,
                "allocation_basis": "shared_keywords_review" if shared else "concept_exclusive",
                "shares_keywords_with": ";".join(shared),
                "level_of_truth": "commercial-outcome",
                "iqs": led.get("iqs", ""), "scored_asof": led.get("scored_asof", ""),
                "valid_from": asof,
            })

    # ---- duplicate / merge proposals (alias-token Jaccard) ----------------
    tokens = {}
    for s in seeds:
        toks = set()
        for a in aliases:
            if a["concept_id"] == s["concept_id"]:
                toks |= {t for t in a["alias_text"].lower().replace("-", " ").split() if len(t) > 3}
        tokens[s["concept_id"]] = toks
    cids = sorted(tokens)
    for i, a in enumerate(cids):
        for b in cids[i + 1:]:
            ta, tb = tokens[a], tokens[b]
            if not ta or not tb:
                continue
            j = len(ta & tb) / len(ta | tb)
            if j >= MERGE_JACCARD:
                key = ("merge_proposal", f"{a}+{b}", b)
                if key not in decided and key not in queued:
                    queue_new.append({"entity_type": "merge_proposal", "entity_key": f"{a}+{b}",
                                      "proposed_concept_id": b,
                                      "match_confidence": f"{j:.2f}",
                                      "reason": f"alias token overlap {sorted(ta & tb)}",
                                      "reviewer": "", "review_status": "",
                                      "corrected_concept_id": "", "reviewed_at": "",
                                      "proposed_at": asof})
                audit.append({"entity_type": "merge_proposal", "entity_key": f"{a}+{b}",
                              "proposed_concept_id": b, "match_type": "alias_jaccard",
                              "match_confidence": f"{j:.2f}",
                              "evidence": f"shared tokens {sorted(ta & tb)}",
                              "disposition": "needs_review", "run_date": asof})

    # concepts with zero product matches -> audit as unmatched
    matched_cids = {r["concept_id"] for r in prod_rows}
    for s in seeds:
        if s["concept_id"] not in matched_cids:
            has_rule = ("product", s["concept_id"]) in rule_conf
            audit.append({"entity_type": "amz_product", "entity_key": "(none)",
                          "proposed_concept_id": s["concept_id"], "match_type": "rule_attribute",
                          "match_confidence": "0.00",
                          "evidence": "no rule defined (no category mapping)" if not has_rule
                                      else "rule matched no ranked product in 90d window",
                          "disposition": "unmatched", "run_date": asof})

    # ---- write ------------------------------------------------------------
    os.makedirs(GEN, exist_ok=True)
    base = ["concept_id", "match_type", "match_confidence", "evidence", "caveats",
            "human_review_needed", "review_status", "reviewer", "valid_from"]
    write(os.path.join(CG, "concept.csv"), concepts,
          ["concept_id", "canonical_name", "level_of_truth", "category", "subcategory",
           "brand", "attributes", "price_band", "status", "merged_into", "created_from",
           "created_at", "updated_at"])
    write(os.path.join(CG, "concept_alias.csv"), aliases,
          ["concept_id", "alias_text", "alias_type", "source", "added_by"])
    write(os.path.join(CG, "concept_product_bridge.csv"), prod_rows,
          ["concept_id", "source", "cb_product_id", "asin", "title", "best_rank_90d",
           "level_of_truth"] + base[1:])
    write(os.path.join(CG, "concept_search_bridge.csv"), search_rows,
          ["concept_id", "search_text", "best_rank", "n_periods", "level_of_truth"] + base[1:])
    write(os.path.join(CG, "concept_social_bridge.csv"), social_rows,
          ["concept_id", "cb_hashtag_id", "hashtag", "followed", "level_of_truth"] + base[1:])
    write(os.path.join(CG, "concept_retailer_item_bridge.csv"), retail_rows,
          ["concept_id", "retailer", "cb_product_id", "retailer_item_id", "title",
           "level_of_truth"] + base[1:])
    write(os.path.join(CG, "concept_epoca_sku_bridge.csv"), sku_rows,
          ["concept_id", "item_code", "asin", "amz_title", "level_of_truth"] + base[1:])
    write(os.path.join(CG, "concept_outcome_bridge.csv"), outcome_rows,
          ["concept_id", "callout_id", "allocation_basis", "shares_keywords_with",
           "level_of_truth", "iqs", "scored_asof", "valid_from"])
    write(os.path.join(GEN, "concept_match_audit.csv"), audit,
          ["run_date", "entity_type", "entity_key", "proposed_concept_id", "match_type",
           "match_confidence", "evidence", "disposition"])
    all_queue = prior_queue + queue_new
    write(queue_path, all_queue,
          ["entity_type", "entity_key", "proposed_concept_id", "match_confidence", "reason",
           "reviewer", "review_status", "corrected_concept_id", "reviewed_at", "proposed_at"])

    # ---- summary ------------------------------------------------------------
    from collections import Counter
    disp = Counter(a["disposition"] for a in audit)
    print(f"concepts={len(concepts)} aliases={len(aliases)}")
    print(f"bridges: product={len(prod_rows)} search={len(search_rows)} "
          f"social={len(social_rows)} retailer={len(retail_rows)} "
          f"epoca_sku={len(sku_rows)} outcome={len(outcome_rows)}")
    print(f"audit dispositions: {dict(disp)}")
    print(f"review queue: {len(queue_new)} new, {len(all_queue)} total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
