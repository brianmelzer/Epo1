# Backtest v2.0 — First Concept-Level Measurements Through the Graph

*The first analyses that consume the Concept Graph
([`CONCEPT_GRAPH_V0.md`](CONCEPT_GRAPH_V0.md)) instead of raw title matching.
Run live **2026-07-05**. Two findings, both honesty-engine grade: one
falsifies a core assumption about search, one exposes the provenance of the
flywheel's flagship outcome label. No alpha is claimed.*

**Scope note (read first).** Concept membership (which products/terms belong
to a concept) is as-of the graph build date, so these are
**pseudo-out-of-sample** measurements — the identity layer knows things a
historical observer wouldn't. This inflates, not deflates, any lead-lag
signal; the null result below survives the bias, which strengthens it. The
full frozen-protocol Backtest v2 (strategies A–G at concept level) requires
historical membership snapshots, which begin accumulating now that the graph
is versioned per build.

---

## 1. Finding 1 — Amazon search rank is a *coincident* indicator, not a leading one

**Method.** For the 8 concepts with the cleanest product + search bridges,
build weekly series over 2024-01 → 2026-07: concept rank intensity
(avg −ln rank of bridged products) and concept search intensity (avg −ln rank
of bridged terms). Correlate *week-over-week changes* at lags −4 to +12 weeks
(`sql/10_backtest_v2_concept_leadlag.sql`). Positive lag = search moves first.

| Concept | n weeks | corr @ lag 0 | best @ positive lag | Verdict |
|---|---|---|---|---|
| CG-0006 oil sprayer | 129 | **+0.258** | +0.236 @ +12 (oscillating) | coincident |
| CG-0008 air-fryer liners | 129 | **+0.250** | +0.104 @ +8 | coincident |
| CG-0013 glass meal prep | 39 | **+0.260** | +0.290 @ +12 | thin n; weak hint at most |
| CG-0010 candle warmer | 95 | −0.091 | +0.127 @ +4 | no signal |
| CG-0011 thermometer | 129 | +0.088 | +0.103 @ +4 | no signal |
| CG-0012 meat chopper | 129 | −0.043 | +0.085 @ +2 | no signal |
| CG-0024 bento | 129 | +0.053 | +0.177 @ +2 | no signal |
| CG-0016 fridge rack | <30 | — | — | members too recent |

**Reading.** Where any relationship exists, it peaks at **lag 0**: when
shoppers search more, the products are *already* climbing that same week. No
concept shows a consistent, monotone positive-lag structure. At weekly,
concept-level granularity, **Amazon search rank does not front-run Amazon
sales rank** — they are two thermometers on the same fever.

**Why this matters and what it does NOT say.** It does not kill search as an
input — coincident confirmation still has value in a composite (volume-proof,
like reviews). It does falsify the comfortable assumption that our existing
search feed supplies the "6–12 months early" signal by itself. The honest
candidates for true lead remain: **emerging-term counts** (new queries
appearing, rather than rank moves of established queries), **social** (where
Backtest v1 saw the best median trajectory), and **external sources not yet
captured** (Google Trends). The lead-time claim must be earned by one of
those, measured on this same harness.

**Caveats.** Weekly search ranks are relative (a term can fall in rank while
growing absolutely in a rising market); gaps where terms drop out of the
ranked universe are differenced across; membership bias noted above.

## 2. Finding 2 — The flagship outcome label has regex-only provenance

**Method.** Rollup template C/D from `sql/09_concept_rollups.sql`, run for
CG-0001 (cast-aluminum ceramic cookware — the ledger's headline concept,
CB-2025-001, IQS 1.000, realized gross $24.5M under the old scoring) against
`shaundatabase.v_so_history`, 2025→today:

| Attribution basis | item_codes | Units | Gross |
|---|---|---|---|
| Exact edges (asinxref-verified) | 3 active of 9 | **6** | **$77** |
| Regex proxy (`cast alum|CA CER`) | **380** | 1,625,101 | **$28.7M** |

**Reading.** The only internal items *provably* linked to the concept (via
the ASIN↔item_code exact chain) contributed essentially nothing — they are a
legacy Ecolution retail line. The $24.5M label rides entirely on a
description regex sweeping 380 SKUs. That does **not** mean the call-out
earned nothing — the real Sam's Club program items simply have no Amazon ASIN
and therefore no asinxref row; they can only enter the graph through curated
`linked_item_codes`. What it does mean: **the flywheel's strongest training
label is currently unverifiable at item level**, and 14 of 26 IQS scores
saturate at 1.0 on the same proxy. The graph converts this from an invisible
assumption into a queryable defect with a named fix.

**The fix, now concrete and prioritized:** curate `linked_item_codes` for the
highest-IQS call-outs first (CB-2025-001 before anything else — one analyst,
one program sheet, minutes of work), enter them in the review queue as
`curated_manual` edges, and let rollup template C recompute concept-attributed
gross. Every curated row moves real dollars from "asserted" to "verified."

## 3. What Backtest v2 (full protocol) needs, in order

1. **Curated outcome edges** for the top-10 IQS call-outs → first
   units-based labels with verified provenance.
2. **Membership snapshots per graph build** (now automatic — the CSVs are
   versioned) → the pseudo-out-of-sample caveat shrinks with each quarter
   that passes.
3. **Emerging-term counter** on the search side (new-query appearance rate
   per concept) → the remaining candidate for measured lead time.
4. Then: strategies A–G re-run at concept level under the frozen v0
   thresholds — which remain untouched: P@10 > 6.5%, median Δρ > −0.192,
   survival > 66%.

## 4. Reproducibility

Both analyses are single parameterized queries
(`sql/10_backtest_v2_concept_leadlag.sql`) over pinned bridge rows (inlined
from the graph CSVs at commit time); reruns against the same data window
reproduce the tables above. Live-data drift applies only to the trailing
week, and the graph build date (2026-07-05) is stamped on every bridge row
used.
