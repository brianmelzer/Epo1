# Crystal Ball — Numbered-Deck SQL Pack

Ready-to-run, validated queries that put **live numbers** into a Crystal Ball
deck instead of static "what's hot" snapshots. These implement Phase 0–1 of
[`../docs/CRYSTAL_BALL_LOOP_V2.md`](../docs/CRYSTAL_BALL_LOOP_V2.md).

All queries run against the `crystalball` schema via the read-only
`Epoca-CrystalBall` connection (SELECT only — the DB role can't create views, so
these are query **templates** you paste and parameterize, not stored objects).

## Files

| File | Formula | What it produces |
|---|---|---|
| `01_breakout_radar.sql` | PWS_v1 (F10) | Per-product **composite score** in a category — `1.5·z(prox) + 0.25·z(vel) + 0.75·z(lnRevGain) + 0.25·priceBand`, the proximity-dominant blend validated by [`../docs/BACKTEST_V1_RESULTS.md`](../docs/BACKTEST_V1_RESULTS.md) (search SDV dropped: concept-level only). Velocity (F1) and acceleration (F2) remain visible as watch columns, but pure velocity was falsified as a standalone ranker |
| `02_feature_lift.sql` | F9 | Which title **features/benefits** are associated with faster movement |
| `03_cross_retailer_gap.sql` | F12 | Concepts surging on one marketplace but thin on another (early, low-risk picks) |
| `04_outer_loop_ledger.sql` | F13–F15 | The flywheel: grade items on real sell-through / margin / reorder, and bridge Crystal Ball rankings to internal outcomes (see [`../docs/OUTER_LOOP_LEDGER_FINDINGS.md`](../docs/OUTER_LOOP_LEDGER_FINDINGS.md)) |
| `05_callout_outcomes.sql` | F13 | Score individual call-out concepts against realized sell-through |
| `06_ledger_refresh.sql` | F13 | One-pass weekly re-score of the whole call-out ledger (run by [`flywheel-weekly.yml`](../.github/workflows/flywheel-weekly.yml)) |
| `07_backtest_hit_rate.sql` | F11 | The **backtest harness**: freeze signals at past dates, score strategy picks against 6/12-month actuals (first run: [`../docs/BACKTEST_V0.md`](../docs/BACKTEST_V0.md)) |
| `08_backtest_v1_composite.sql` | F10/F11 | Backtest v1 multi-source strategies A–G + ablation (results: [`../docs/BACKTEST_V1_RESULTS.md`](../docs/BACKTEST_V1_RESULTS.md)) |
| `09_concept_graph_extracts.sql` | — | Source extracts feeding the **Concept Graph v0** builder (see [`../docs/CONCEPT_GRAPH_V0.md`](../docs/CONCEPT_GRAPH_V0.md)) |
| `09_concept_rollups.sql` | — | Concept-level rank/search/outcome rollups + double-count check for Backtest v2 |
| `10_backtest_v2_concept_leadlag.sql` | F6 | Backtest v2.0: concept-level search↔rank lead-lag + outcome-label provenance check (findings: [`../docs/BACKTEST_V2.md`](../docs/BACKTEST_V2.md)) |

## How to read the signals

- **Rank** in `crystalball` is *lower = more popular*. We work in
  `ρ = -ln(rank)` so a 80→40 move and a 40→20 move count as equal momentum.
- **Velocity (F1)** > 0 → climbing. Finds *emerging* items.
- **Acceleration (F2)** > 0 with velocity > 0 → still speeding up (the buy
  signal), not just a one-off spike.
- **Review velocity (F3)** → reviews accrue with units sold, so this is the best
  in-dataset **sales proxy**. It finds *actual volume* even when rank velocity is
  moderate. Example (validated 2026-07-02): CAROTE 44-pc gained **25,176 reviews
  in 30 days** — a volume winner the pure-velocity list underweights.

**Use velocity + acceleration to find what's *emerging*, and review velocity to
confirm *real volume*. Rank the deck on the combination, not any one alone.**

## Category → ID map (validated 2026-07-02)

Amazon IDs below are **region 1 = US** (the region carrying the classic
`Kitchen & Dining` parent). Other regions exist (2/4/5/6) for other locales.

### Amazon (`crystalball.list`, filter `cb_region_id = 1`, join on `cb_category_id`)

| Roadmap category | `cb_category_id` |
|---|---|
| Cookware (broad) | 5 |
| Cookware Sets | 35 |
| Specialty Cookware | 45 |
| Bakeware | 2 |
| Food Storage | 84 |
| Kitchen Utensils & Gadgets | 11 |
| Tool & Gadget Sets | 62 |
| Hydration (Sports Water Bottles) | 91 |
| Glassware & Drinkware | 8 |
| Beverage dispensers | 26 (Carafes & Pitchers) + 112 (Serveware) + title keyword `dispenser` |
| Candles & Holders | 925 |

### Walmart (`crystalball.wm_list`, filter on `cb_list_id`)

| Roadmap category | `cb_list_id` |
|---|---|
| Cookware Sets | 143 |
| Ceramic Cookware | 149 |
| Stainless Steel Cookware | 150 |
| Induction Cookware | 140 |
| Bakeware / Bakeware Sets | 155 / 158 |
| Food Storage Containers | 9 |
| Kitchen Tools & Gadgets | 19 |
| Kitchen & Cooking Utensil Sets | 89 |
| Cool Kitchen Gadgets | 64 |
| Drinkware / Tumblers / Water Bottles / Travel | 127 / 131 / 133 / 130 |
| Knife Sets / Kitchen Knives | 106 / 116 |

### Five Below

Five Below organizes by merchandising bucket, **not** product category
(`f_below_category` = New & Now, Room, Party, Arts & Crafts, Five Beyond). Use
it as a **cross-retailer confirmation** signal (does a concept also appear
there?), not for category-level velocity.

## Parameters

Each file marks tunables with `-- PARAM`. The common ones:
- **Anchor date** — replace `date '2026-07-02'` with the latest `cb_stamp`
  (`SELECT max(cb_stamp) FROM crystalball.list_item`).
- **Category** — swap the `cb_category_id` / `cb_list_id` per the map above.
- **Windows** — `14` (recent), `30–44` (prior), `60–74` (baseline) days.

## Caveats (learned from validation)

- **Feature lift (F9) must be paired with volume.** Over a broad, long-tail
  category the *average* product mean-reverts (baseline velocity is negative
  because fading long-tail items dominate the count), so raw rank-velocity lift
  reads negative for almost every feature. Measure lift against **review
  velocity** on higher-traffic products (top ~50) for an honest read — a few
  titanium / detachable-handle SKUs rocket while the average one declines.
- **Require minimum observations** per window (`HAVING count(*) >= N`) to avoid
  one-snapshot noise.
- **Rank compression** near the top is why we use `-ln(rank)`; don't compare raw
  rank deltas.
