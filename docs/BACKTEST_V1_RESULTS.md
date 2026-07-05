# Backtest v1 — Multi-Source Composite

*Second run of the F11 backtest harness
([`../sql/08_backtest_v1_composite.sql`](../sql/08_backtest_v1_composite.sql)),
executed live against the `crystalball` data lake on **2026-07-05** (data
edge 2026-07-03). Question under test: does a composite Crystal Ball signal —
blending proximity, velocity, review volume, Amazon search intent, social
attention, and commercial filters — beat the simple bestseller-proximity
baseline from [`BACKTEST_V0`](BACKTEST_V0.md)? This run is NOT about proving
velocity works (v0 already falsified naive velocity); it is about whether
adding more data sources buys measurable predictive edge.*

---

## 1. Design

**Frozen protocol (v0, reused unchanged and re-validated).** Same 7 Amazon US
categories × 3 freeze dates (2024-07-01, 2025-01-01, 2025-07-01) × top-10
picks = 200 picks per strategy (Candles lacks history at the first freeze).
Same challenger universe (top-100 list members in the 14 days before t0,
≥ 5 snapshots, avg recent rank > 10), same signal windows, same outcome
windows (t0+150..210 and t0+330..390 days), same metrics. **Validation:**
strategies A/B/C in this run reproduce v0's published counts *exactly*
(A: 101/13/38, B: 56/1/9, C: 132/2/17 at 6 months; 86/6/31, 61/2/6, 110/2/14
at 12 months).

*One definitional nuance:* v1 computes median Δρ over strict survivors
(≥ 5 outcome snapshots), which is what v0's prose specified; v0's SQL also
included partially-observed rows (1–4 snapshots). Under the strict
definition the v0 incumbents recompute to −0.588 (A) and −0.186 (C) at 6mo,
vs −0.596 / −0.192 as published. Both sets are shown where it matters; all
v1 comparisons are internally consistent (same definition for every row).

**Data-source verification (done before designing strategies):**

- **Search (F4):** `amz_search` + `amz_term_period` hold contiguous *weekly*
  top-25,000 US search terms from **2020-10-25** onward — genuinely predates
  every freeze date. Strategy D is testable. ✔
- **Social (F5):** `sm_post_hashtag`/`sm_collection` cover **2023-04**
  onward, also predating every freeze — but joinability to products is by
  hashtag-text ⊂ product-title matching only, and the ~400 curated hashtags
  are category/concept-level (`bakeware`, `airfryer`, `waterbottle`), not
  product-level. Strategy E is testable but structurally weak at
  within-category discrimination. Engagement-weighted SL (views) was
  **not** computable: joining 64M `sm_post_hashtag` × 176M
  `sm_user_engagement` rows (no date indexes) exceeds the 60-second query
  gateway, so the pre-registered fallback — posting-volume growth — was
  used. Stated plainly: **E measures how fast people are posting to a
  matched hashtag, not how many views those posts get.**

**Signals (all strictly as-of t0; z() = z-score within the (category, t0)
challenger universe; missing z-inputs imputed to 0):**

| Signal | Formula |
|---|---|
| PROX | z(−ln r_now), r_now = avg rank last 14d |
| zV (F1) | z((−ln r_now) − (−ln r_mid)), r_mid = avg rank t0−44..−30d |
| zLRG (F3) | z(ln(1 + max(rev_gain, 0))), rev_gain = 30d review-count gain |
| zRAT | z(avg rating, 14d) |
| zSDV (F4) | z(max over matched search terms of Δρ_search), Δρ_search = (−ln rank_wk≤t0) − (−ln rank_wk≤t0−56d); terms ≥ 8 chars, multi-word, matched as substrings of the title |
| zSL (F5) | z(max over matched hashtags of ln(1+posts_28d) − ln(1+posts_prior28d)); alphabetic tags ≥ 5 chars, ≥ 20 posts/56d, matched against the space-stripped title |
| zMOAT | z(ln(1+rev_now) − ln(1+median reviews of current top-10 incumbents)) |
| NEW | 1 if `cb_first_ranking` > t0 − 180d |
| PB | 1 if avg price (14d) within [p25, p75] of the full category top-100 price distribution at t0 |

**Strategies** (10 picks per cell, `cb_product_id` tie-breaks):

- **A** bestseller proximity: best current rank (v0 verbatim — the baseline).
- **B** pure velocity (v0 verbatim — the falsified control, kept as-is).
- **C** velocity + volume: velocity > 0, ranked by 30d review gain (v0 verbatim).
- **D** search intent: ranked by SDV (matched products only).
- **E** social attention: ranked by SL (matched products only).
- **F** product proof: `1.0·zLRG + 0.5·zRAT + 0.5·PROX + 0.5·NEW + 0.5·PB`.
- **G** full composite (F10-style PWS). Five candidate weight vectors were
  written down **before any evaluation** (see the SQL header and the
  session's pre-registration notes), the winner selected on the TRAIN
  freeze (2024-07-01) only — by 6mo top-10 wins, then survival, then median
  Δρ — and then evaluated frozen on the two later freezes. Train result:
  G2 won (4 top-10 wins vs 1/1/0/2 for G1/G3/G4/G5). **The v1 composite is
  therefore:**

```
PWS_v1 (G2) = 1.5·z(−ln r_now) + 0.25·z(V) + 0.75·z(ln(1+rev_gain))
            + 0.5·z(SDV) + 0.25·PB
```

## 2. Results

### 2.1 Strategy comparison — 6-month horizon, all 3 freezes pooled (n = 200 picks each; windows complete)

| Strategy | Survived | Top-10 winners (P@10) | Top-20 winners (P@20) | Median Δρ (survivors) |
|---|---|---|---|---|
| A — bestseller proximity (baseline) | 101 (50.5%) | **13 (6.5%)** | 38 (19.0%) | −0.588 |
| B — pure velocity (falsified control) | 56 (28.0%) | 1 (0.5%) | 9 (4.5%) | −0.485 |
| C — velocity + volume (v0 incumbent) | 132 (66.0%) | 2 (1.0%) | 17 (8.5%) | −0.186 |
| D — search intent | 61 (30.5%) | 3 (1.5%) | 6 (3.0%) | −0.182 |
| E — social attention | 103 (51.5%) | 3 (1.5%) | 14 (7.0%) | **−0.010** |
| F — product proof | 133 (66.5%) | 12 (6.0%) | 36 (18.0%) | −0.263 |
| **G — composite PWS_v1 (G2)** | 122 (61.0%) | **13 (6.5%)** | **39 (19.5%)** | −0.551 |
| G5 — product-only composite (candidate) | **136 (68.0%)** | 11 (5.5%) | 35 (17.5%) | −0.527 |

(Other composite candidates, for the record: G1 6/200 top-10, 112 survived;
G3 5/200, 119; G4 3/200, 85.)

### 2.2 Strategy comparison — 12-month horizon, pooled (n = 200; the 2025-07-01 freeze contributes a PROVISIONAL window — 38 of 61 outcome days at the 2026-07-03 data edge)

| Strategy | Survived | Top-10 winners | Top-20 winners | Median Δρ (survivors) |
|---|---|---|---|---|
| A — baseline | 86 (43.0%) | 6 (3.0%) | 31 (15.5%) | −0.627 |
| B — pure velocity | 61 (30.5%) | 2 (1.0%) | 6 (3.0%) | −0.633 |
| C — velocity + volume | 110 (55.0%) | 2 (1.0%) | 14 (7.0%) | −0.182 |
| D — search intent | 61 (30.5%) | 1 (0.5%) | 5 (2.5%) | **−0.040** |
| E — social attention | 90 (45.0%) | 1 (0.5%) | 12 (6.0%) | −0.089 |
| F — product proof | 113 (56.5%) | 6 (3.0%) | 27 (13.5%) | −0.327 |
| **G — composite PWS_v1** | 103 (51.5%) | 6 (3.0%) | **36 (18.0%)** | −0.536 |
| G5 — product-only composite | **121 (60.5%)** | 5 (2.5%) | 29 (14.5%) | −0.502 |

### 2.3 Train / eval split for the composite (no in-sample tuning)

G2's weights were chosen on 2024-07-01 only. On the two held-out freezes
(2025-01-01 + 2025-07-01, n = 140), 6-month horizon:

| | Survived | P@10 | P@20 |
|---|---|---|---|
| A — baseline | 69 (49.3%) | 8 (5.7%) | 23 (16.4%) |
| **G — PWS_v1** | **88 (62.9%)** | **9 (6.4%)** | **24 (17.1%)** |

Held-out medians per freeze: G −0.501 / −0.588 vs A −0.438 / −0.785. So on
data it was not tuned on, the composite beats the baseline on every count
metric and on trajectory at the freeze where the baseline collapses — but
the precision edge (9 vs 8 winners) is one pick and far inside noise.

### 2.4 Ablation — which signal actually adds predictive power? (6mo, pooled, n = 200 per row)

Unit-weight additive z-score ladder, same protocol:

| Variant | Top-10 | Top-20 | Survived | Median Δρ |
|---|---|---|---|---|
| baseline only (PROX ≡ A) | **13** | 38 | 101 | −0.588 |
| + velocity (PROX+zV) | 3 | 20 | 70 | −0.629 |
| + search (+zSDV) | 2 | 13 | 63 | −0.506 |
| + social (+zSL) | 4 | 17 | 76 | −0.471 |
| + reviews (+zLRG) | 5 | 19 | 95 | −0.429 |
| + commercial filters (PB gate + 0.5·zMOAT) | 5 | 24 | 123 | −0.419 |
| full composite (PWS_v1, proximity re-weighted 1.5×) | **13** | **39** | 122 | −0.551 |

**Verdict, stated bluntly:** at equal weight, *every* added signal destroys
the baseline's precision — adding velocity alone drops top-10 winners from
13 to 3, and search/social/reviews/commercial never claw it back (2→4→5→5).
The signals that genuinely add power are, in order: (1) **review-volume
growth (F3)** — it drives survival (95→123 with commercial filters; F and
G5, the review-heavy blends, hit 66.5% and 68.0% survival) and halves the
median decline; (2) **the commercial filter** (price-band + review-moat) —
+28 survivors and +5 top-20 winners on top of abl4 for free; (3)
**proximity itself**, which must be re-weighted to dominance (1.5×) before
the composite recovers baseline precision. **Search adds nothing measurable
at product level** (it *subtracts* in the ladder; D alone: 3/200 winners,
30.5% survival — its only virtue is a mild median). **Social is noisy and
only concept-level joinable** — E's remarkable median (−0.010, best of all
strategies, and 51.5% survival with zero proximity information) says
hashtag-matched products mean-revert less, but it converts almost nothing
(3/200) and cannot separate products within a category, so it reads as a
category-heat tilt, not a product signal.

### 2.5 Scoreboard vs the frozen v0 targets (6mo, pooled)

| Frozen target | Best v1 result | Beaten? |
|---|---|---|
| Precision@10 > 6.5% (baseline A) | 6.5% (G2) — a tie, 13 vs 13 | **No** |
| Median Δρ better than −0.192 (C; −0.186 under the strict-survivor definition) | E −0.010, D −0.182 | Yes, but only by strategies with ~1.5% precision |
| Survival > 66% (C) | G5 68.0%, F 66.5% | Yes (marginally) |

**No strategy beats all three frozen numbers at once, and no composite beats
the baseline's precision@10.** That is the headline, and it should not be
oversold in the other direction either: the composite matches baseline
precision while surviving 21 more picks per 200 and losing less rank —
i.e. it dominates weakly, it does not win outright.

## 3. Honest findings

1. **The composite does not beat the free baseline where it counts most.**
   Precision@10 is a tie (13 = 13). If the pitch is "our model finds next
   quarter's bestsellers better than sorting by current rank," v1 does not
   yet support that pitch.
2. **What the composite does buy is downside protection at equal
   precision.** Same 13 winners, but 122 vs 101 survivors (+10.5 pts),
   39 vs 38 top-20 winners, and a better median (−0.551 vs −0.588); on the
   held-out freezes it beats the baseline on every count metric. For a
   buyer, picks that don't die matter — but this is a risk story, not an
   alpha story.
3. **Review-volume growth is the one confirmed non-price signal.** v0's
   finding survives contact with more data sources: F3 is what moves
   survival and trajectory (F, G5, abl4→abl5). Nothing else comes close.
4. **Search intent, as implementable today, is not a product-level
   signal.** Weekly top-25k terms matched into titles produce
   concept-level, heavily tied SDV values (in Hydration 2024-07, ~80% of
   matched products share one generic term's score). D's 3/200 precision
   and the abl2 *drop* are the measured result. It might work at the
   concept/keyword level (its medians are consistently mild: −0.182 / −0.040)
   — it does not work for ranking individual ASINs.
5. **Social is honest-to-goodness weak, and we measured why.** Only ~400
   curated category hashtags exist, matching is by name-in-title, and
   engagement weighting is computationally out of reach in this
   environment. The volume-growth version tilts toward warm categories
   (best median of all strategies, −0.010) but picks almost no winners.
   Treat F5 as a category-heat context signal, not a product ranker.
6. **Pure velocity remains falsified** — 1/200 at 6 months, worst
   survival (28%), and it is the single most destructive addition in the
   ablation ladder. v0's conclusion stands under composite treatment.

## 4. What result *would* prove predictive edge

The v2 bar, on this same frozen protocol: a composite that (a) beats
**precision@10 > 6.5%** pooled *and* on held-out freezes, (b) holds
**survival > 66%**, and (c) beats **median Δρ −0.186 (strict)** —
simultaneously, with weights chosen on train freezes only. Statistically,
+1 winner in 200 is noise; a defensible claim needs roughly ≥ 20/200
(10%) top-10 precision or the same 6.5% at materially higher K. A cheap
sharpening first step: F + commercial filter with proximity 1.5× (merge the
G2 and G5 lobes) — F alone already gets 12/200 with C-level survival.

## 5. Key risks & caveats

- **Small samples everywhere.** 13 vs 12 vs 11 winners across 200 picks;
  every precision difference in this report is within ±1σ of a binomial.
  Do not promote or demote any strategy on precision alone from this run.
- **Provisional 12-month cell.** The 2025-07-01 freeze's 12mo window covers
  38/61 days at the data edge (2026-07-03); its survivors and winners can
  still drift (v0 measured exactly this drift between its two runs).
- **Median-definition nuance** (§1): v1 medians are strict-survivor;
  v0-published medians included partial rows. Deltas ≈ 0.006–0.008.
- **Search-signal construction risk.** The 2025-01-01 freeze compares a
  Christmas search week against early November — holiday mix shifts
  category-symmetrically but is not neutral. Term-title substring matching
  favors generically-titled products.
- **Social look-ahead residue.** Post counts by publish date are observed
  through *today's* collection; posts published before t0 could have been
  collected after t0. Both windows inflate alike, so the growth ratio is
  mostly clean, but it is not a literal point-in-time reconstruction.
  Collection-roster changes (home-décor tags added 2024-late) shift the
  matched-tag mix between freezes.
- **Concept-level joins.** Both D and E assign many products identical
  scores (ties broken by product id — deterministic but arbitrary).
  Their true resolution is the concept, not the ASIN.
- **Rank is still a demand proxy, not units** — the outer-loop ledger
  (F13 IQS) remains the commercial ground truth this harness cannot see.
- **Execution note.** The 60s statement gateway forced the run to be staged:
  Section 1 (search) executed per (t0 × category) cell — 20 cells (Candles
  2024-07 has no cohort); Section 2 (social) in one pass; Section 3 with
  the extraction outputs inlined as VALUES (exact values preserved in the
  committed SQL, so the file replays end-to-end). Nothing was sampled —
  all 7 categories, all 3 freezes, the full 25k-term weekly search
  universe (filtered to multi-word terms ≥ 8 chars), and all followed
  hashtags (alphabetic, ≥ 5 chars, ≥ 20 posts/56d) are in.

## 6. Data needed next (in value order)

1. **Product-level search linkage** — Amazon Brand-Analytics-style
   term→ASIN click/conversion shares (or at minimum search-term *click*
   attribution), so F4 stops being a title-substring guess. This is the
   single biggest gap between "search adds nothing" and "we can't see it."
2. **Deeper search rank history per term** (full-rank beyond top-25k and
   sub-weekly cadence) to build real search velocity/acceleration.
3. **Social→product linkage**: post-level product tags/URLs (many TikTok
   shop posts carry ASINs), and an engagement rollup table keyed by
   (hashtag, day) so views-weighted SL fits inside any query budget —
   the raw rows exist (176M) but are unusable without pre-aggregation.
4. **A units-based label** — join to `shaundatabase`/`epocasql`
   sell-through for called-out items (F13/F15) so the composite trains on
   money, not rank.
5. **Category-competitiveness time series** (churn of the top-100, entry
   rates) captured at freeze time — the PB/MOAT commercial filter added
   real survival; a richer competition feature is the cheapest next win.
6. **Walmart replication** (`wm_list_item`, since 2025-05): the first
   6-month out-of-marketplace validation window is already available.

---

*Reproduction: run `../sql/08_backtest_v1_composite.sql` Section 3
verbatim (self-contained, ~70KB with inlined extraction outputs); or
re-derive Sections 1–2 first to refresh the VALUES. Validated 2026-07-05;
strategy A/B/C rows must — and do — match BACKTEST_V0 exactly.*
