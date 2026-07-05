# Concept Graph v0 — The Product Identity Spine

*The first durable mapping layer connecting search terms, social tags, Amazon
products, retailer items, Epoca SKUs, and commercial outcomes into shared
product concepts. Built and validated against live data **2026-07-05**.*

**Why this exists.** Backtest v1's ablation ([`BACKTEST_V1_RESULTS.md`](BACKTEST_V1_RESULTS.md))
showed the multi-agent council's weakest signals failed at the *identity join*,
not the signal: search added nothing at product level because title-substring
matching is concept-level; social couldn't attach to products at all; and the
flywheel's regex scoring left two call-outs at zero matches while double-counting
$24M of gross across overlapping cookware concepts. The architecture named the
Concept Graph the crown-jewel subsystem ([`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) §1.3/§3.2);
this is its v0 — deliberately small, inspectable, and correctable.

**Where it lives.** The lake connection is read-only, so the graph is
**versioned CSVs in-repo** (`data/concept_graph/`), built deterministically by
`scripts/concept_graph_build.py` from authored seeds/rules plus SQL extracts
(`sql/09_concept_graph_extracts.sql`). Corrections are PRs; git history is the
audit trail. No graph database, by design.

---

## 1. What was built (validated run, 2026-07-05)

| Artifact | Count | Notes |
|---|---|---|
| `concept.csv` | **29 concepts** | seeded from all 34 ledger call-outs; 5 multi-call-out merges (cast-aluminum ×4, candle-warmer ×2, charcuterie ×2) |
| `concept_alias.csv` | 132 aliases | ledger keywords + search/social patterns |
| `concept_product_bridge.csv` | 105 edges | 24 concepts matched to ranked Amazon products (90-day window) |
| `concept_search_bridge.csv` | 85 edges | level_of_truth = **concept**; e.g. "candle warmer lamp" @ search rank 20 |
| `concept_social_bridge.csv` | 20 edges | 1 concept-level + 19 category-level — labeled, not laundered |
| `concept_retailer_item_bridge.csv` | 14 edges | Walmart sample (title-only, confidence ×0.9) |
| `concept_epoca_sku_bridge.csv` | 39 edges | asinxref exact ASIN↔item_code chain + rule-based concept assignment |
| `concept_outcome_bridge.csv` | 34 edges | every call-out mapped; **16 flagged `shared_keywords_review`** — the double-counting exposure, now visible |
| `generated/concept_match_audit.csv` | 272 rows | 43 auto-accepted · 224 needs-review · 5 unmatched |
| `concept_review_queue.csv` | 224 rows | incl. **4 duplicate-concept merge proposals** |

**The two flywheel zero-match concepts are fixed at the signal layer:**
CB-2025-006 (oil sprayer → CG-0006) now has 5 product edges + 5 search terms;
CB-2025-013 (glass meal prep → CG-0013) has 5 + 5. Their *Epoca SKU* edges
remain open review items — correctly, because Epoca has no confirmed internal
item for either; the graph now says so explicitly instead of scoring them 0.

**Honestly unmatched (5):** CG-0005 towel warmer (no category mapping — "Home"
isn't collected), CG-0004 ice-maker tumbler, CG-0009 electric lunch box,
CG-0021 stackable air fryer (appliances off-list), CG-0025 ceramic
baker+roaster. Unmatched is a disposition, not a failure — it routes to rule
improvement or new collection, visibly.

## 2. Levels of truth

Every edge carries `level_of_truth ∈ {product, concept, category, retailer,
brand, commercial-outcome}`. Search edges are **concept**-level; social edges
are mostly **category**-level (hashtags like `kitchengadgets` describe shelves,
not SKUs — one exception found: `ceramiccookware` ↔ CG-0001). Backtest v2 must
consume signals at their labeled level; the rollup templates
(`sql/09_concept_rollups.sql`) enforce this by construction.

## 3. Match taxonomy & confidence bands

| match_type | Band | Meaning |
|---|---|---|
| `exact_key` / `curated_manual` | 0.95–1.00 | asinxref keys; human-approved rows |
| `exact_key_via_rule` | rule band | ASIN↔item_code exact, concept assignment rule-based |
| `rule_attribute` | 0.55–0.80 | title/category regex from `matching_rules.csv` |
| `rule_keyword` | 0.50–0.90 | search/social term patterns |
| `alias_jaccard` | j-score | duplicate-concept merge proposals |

Confidence **< 0.85 ⇒ `human_review_needed=true`** and a queue row.
Confidences are heuristic bands, not calibrated probabilities. Consumers pick
floors: money math (outcome labels, gross attribution) uses approved/≥0.85
edges only; exploratory scans may accept lower.

The noise the rules caught is deliberately preserved as review evidence:
"charcuterie" swept in cutting boards, "silicone" pulled Primula espresso
gaskets into the tool-set concept, "cast aluminum" matched Walmart burger
presses, "tri-ply" caught butter warmers. Each sits in the queue with its
evidence string — this is what transparent matching looks like at v0.

## 4. Human-in-the-loop review

`concept_review_queue.csv` columns: proposed match, confidence, reason,
reviewer, review_status (approved/rejected), corrected_concept_id, timestamps.
The workflow: edit the queue → PR → next build **promotes approved rows to
`curated_manual` (0.95) and permanently retires rejected ones** (rejections are
remembered; nothing re-proposes). The builder is idempotent — rebuilds add
zero duplicate proposals and never overwrite human decisions. Suggested
cadence: a few rows per week alongside the flywheel refresh, highest-IQS
concepts first.

**Merge proposals awaiting review:** CG-0019+CG-0023 (dispensers, j=0.75),
CG-0007+CG-0018 (stackable/ceramic bakeware, j=0.67), CG-0010+CG-0027
(candle warmer / soy-candle set, j=0.60 — likely *related*, not duplicate),
CG-0013+CG-0014 (glass storage, j=0.38).

## 5. How this improves Backtest v2 and the flywheel

1. **Search becomes a legitimate concept-level predictor** — matched term
   families roll up to one demand series per concept (template B), tested
   against concept-level rank movement (template A), not forced into product
   claims.
2. **Social contributes at its honest level** — category-heat series, plus the
   rare concept-level tag; `followed_since` on every edge keeps backtest
   coverage honest.
3. **Units-based labels replace rank-only labels** — outcome rollup (template
   C) joins realized units/gross via exact item_code edges only, replacing the
   synonym-regex scoring in `06_ledger_refresh.sql` row by row as curation
   lands.
4. **Duplicate counting becomes visible and fixable** — 16 of 34 call-outs
   share keywords with another concept (worst: the ceramic-bakeware /
   cast-aluminum family that previously double-counted gross). Template D
   makes any item_code claimed by two concepts a defect you can query.
5. **Concept-attributed vs raw gross separate cleanly** — `allocation_basis`
   on every outcome edge distinguishes exclusive from shared-keyword
   attribution.

## 6. Deferred (v0 boundary)

Embeddings/pgvector, LLM adjudication, graph databases, image matching,
write-back to the lake, automatic merges, full Walmart/Five Below coverage,
use-case ontology, sentiment. Each becomes worthwhile only after the review
queue proves the rule tier's precision ceiling.

## 7. Risks

Over-merge vs under-merge (mitigated: merges only via reviewed proposals,
reversible via `merged_into`); rule noise laundering into money math
(mitigated: 0.85 floor + exact-only outcome rollups); review bandwidth (224
rows is a deliberate v0 posture — scope to 7 categories keeps it dozens per
week); heuristic confidence mistaken for probability (documented here and in
every file header).
