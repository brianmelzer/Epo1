# Backtest v0 — The First Measured Hit Rate

*The first run of the F11 backtest harness
([`../sql/07_backtest_hit_rate.sql`](../sql/07_backtest_hit_rate.sql)),
executed live against the `crystalball` data lake on **2026-07-03**. This is
the number [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) Phase 1
demands the platform produce before anything else: not a demo, but our own
measured performance — including where our naive signal loses.*

---

## 1. Design

**Question.** If we had frozen Crystal Ball's signals at a past date and
picked 10 products per category, how would those picks have performed 6 and
12 months later — versus the naive strategy a buyer could run for free?

**Setup.** 7 roadmap Amazon categories (Cookware Sets, Bakeware, Food
Storage, Gadgets, Hydration, Drinkware, Candles) × 3 freeze dates
(2024-07-01, 2025-01-01, 2025-07-01) × top-10 picks = **200 picks per
strategy** (Candles lacks history at the first freeze date). Universe per
cell: "challengers" — products on the category's top-100 lists in the 14 days
before the freeze, ≥ 5 snapshots, average rank worse than 10 (incumbent
top-10 bestsellers excluded: the question is who *becomes* a winner).
Signals computed strictly as of the freeze date — no look-ahead.

| Strategy | Pick rule |
|---|---|
| **A — bestseller-proximity baseline** | Best current rank (i.e. ranks 11, 12, …) — the free, naive strategy |
| **B — pure F1 velocity** | Highest rank velocity, 14d window vs 30–44d window |
| **C — velocity + volume confirmation** | Velocity > 0, ranked by 30-day review-count gain (F3) |

**Outcomes.** *Survival* = still on the lists (≥ 5 snapshots) in the outcome
window; falling off the top-100 counts as a loss. *Winner* = average rank ≤ 10
(also reported: ≤ 20) in the window. *Trajectory* = median Δρ where
ρ = −ln(rank), survivors only. Outcome windows: days 150–210 (6mo) and
330–390 (12mo) after the freeze.

---

## 2. Results (n = 200 picks per strategy)

### 6-month horizon

| Strategy | Survived | Top-10 winners | Top-20 winners | Median Δρ (survivors) |
|---|---|---|---|---|
| A — bestseller proximity | 101 (50.5%) | **13 (6.5%)** | 38 (19.0%) | −0.596 |
| B — pure velocity | 56 (28.0%) | 1 (0.5%) | 9 (4.5%) | −0.519 |
| C — velocity + volume | **132 (66.0%)** | 2 (1.0%) | 18 (9.0%) | **−0.192** |

### 12-month horizon

| Strategy | Survived | Top-10 winners | Top-20 winners | Median Δρ (survivors) |
|---|---|---|---|---|
| A — bestseller proximity | 86 (43.0%) | 6 (3.0%) | 31 (15.5%) | −0.647 |
| B — pure velocity | 61 (30.5%) | 2 (1.0%) | 6 (3.0%) | −0.664 |
| C — velocity + volume | **110 (55.0%)** | 3 (1.5%) | 15 (7.5%) | **−0.177** |

Per-category splits (same run) show the pattern holds everywhere: A leads on
absolute top-10 conversion in most categories; C leads on survival and
trajectory in every category; B trails on both nearly everywhere.

### What strategy C actually caught (6-month top-20 winners, 18 of 200)

A sample of the deep climbs — picks the proximity baseline cannot make by
construction:

| Category | Frozen at | Product | Rank then → 6mo later |
|---|---|---|---|
| Food Storage | 2025-01 | Freshware deli containers 50-set | 57 → 17 |
| Bakeware | 2024-07 | Air-fryer disposable liners 120 pc | 53 → 20 |
| Bakeware | 2025-07 | Heavy-duty cooling racks 2 pc | 41 → 16 |
| Food Storage | 2024-07 | Vtopmart glass meal-prep 8-pack | 39 → 15 |
| Candles | 2025-01 | Yankee Candle MidSummer's Night | 16 → 5 |
| Cookware Sets | 2025-07 | Astercook 21-pc ceramic set | 23 → 19 |

---

## 3. Findings — what the harness just taught us

1. **Mean reversion is the house edge.** The median challenger *declines*
   under every strategy, and roughly half of all picks fall off the top-100
   entirely within 6 months. Any scoring model that doesn't carry an explicit
   mean-reversion prior will systematically over-promise. This is now
   quantified: the baseline's median survivor loses ~0.6 log-rank.
2. **Pure F1 velocity is noise-chasing — worse than the free baseline.**
   One winner in 200 picks at 6 months, and the worst survival rate (28%).
   A single 14-day velocity window mostly catches spikes already collapsing.
   The naive version of "we rank by momentum" is hereby falsified — better
   that our own harness says it than a buyer's post-mortem.
3. **Volume confirmation transforms the signal.** Requiring positive velocity
   *and* ranking by 30-day review gain (a units-sold proxy) more than doubles
   survival vs pure velocity (66% vs 28%), beats even the baseline's
   survival by 15 points, and cuts the median survivor's decline by ~70%
   relative to baseline (−0.19 vs −0.60). It also finds deep climbers
   (rank 57→17, 53→20) that proximity can't reach. The SQL-pack caveat
   ("pair velocity with volume") is now a measured law, not advice.
4. **The two metrics answer different buyer questions — keep both.** The
   absolute top-10 criterion structurally favors the proximity baseline (its
   picks start at rank 11–20 and need a one-step move). Proximity answers
   *"who will be on the bestseller shelf next quarter"* (6.5% precision@10);
   volume-confirmed velocity answers *"who is genuinely climbing"* (best
   trajectory, best survival). The composite PWS must fuse both — momentum
   for discovery, proximity/stability for conversion.

## 4. The numbers to beat

Every future model version (the F10 composite PWS, and each retrain after
it) must beat, on this same frozen-universe protocol:

- **Precision@10 (6mo, top-10): > 6.5%** — the proximity baseline.
- **Median survivor Δρ (6mo): > −0.192** — the volume-confirmed strategy.
- **Survival (6mo): > 66%** — same.

Per the architecture (§3.3), this comparison becomes a CI gate: a candidate
model that fails to beat the incumbent on the held-out windows is not
promoted.

## 5. Caveats

- **Truncated final window.** For the 2025-07-01 freeze, the 12-month
  outcome window (2026-05-27 → 2026-07-26) is cut off at the data edge
  (2026-07-03); survivors there are scored on ~38 of 61 days. 6-month
  windows are complete for all freezes.
- **Rank is a demand proxy, not units.** Winners here are marketplace-rank
  winners; the ledger's F13 IQS remains the commercial ground truth. F15
  will map one to the other.
- **Survivor-conditional trajectory.** Median Δρ is computed over survivors
  for all strategies alike; survival itself is reported separately so the
  conditioning is visible.
- **Category-average rank.** Products appearing on multiple lists within a
  category are averaged, consistent with the SQL pack's conventions.

## 6. Next iterations of the harness (cheap now that it exists)

1. Add **F2 acceleration** and a **longer signal window** (6–8 weeks) to
   strategy variants — test whether sustained momentum beats 14-day momentum.
2. Add an **F8 lifecycle gate** (only pick Emerging/Growth stages) — the
   hypothesis is that it removes exactly the collapsing-spike picks that sank
   strategy B.
3. Score the **composite PWS** (F10) against the §4 numbers and publish the
   comparison in this document's next version.
4. Extend to **Walmart lists** (data since May 2025 — first 6-month backtest
   window is already available).
