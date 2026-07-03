# Crystal Ball Loop 2.0 — Upgrade Strategy & Plan

*How to turn the Crystal Ball trend workflow from a curated deck generator into a
quantified, self-correcting prediction engine that calls the best-selling trends
6–12 months out.*

**Prepared for:** Epoca / Crystal Ball product-development team
**Context:** We are now directly plugged into three capabilities that used to be
separate — the **Crystal Ball data lake** (live SQL), the **Librarian**
(internal document + email knowledge base), and **Fable's** research/analysis
reasoning. This document is the plan to combine them and maximize the loop.

---

## 0. Two loops, one flywheel

There are actually **two** loops, nested. Getting the relationship right is the
whole game.

**The outer loop — the commercial flywheel.** This is the real business:

```
   ┌──▶ call out an item ─▶ pitch to buyer ─▶ buyer likes it ─▶ MRF (spec)
   │                                                               │
   │                                                     price comparison
   │                                                               │
   │                                                     choose factory
   │                                                               │
   │                                                        buy (PO)
   │                                                               │
   │                                                          ship
   │                                                               │
   │                                                     sells well?
   │                                                               │
   └──── reorder or variate the item ◀──────────────────────────┘
```

Every hand-off leaks, and each is moved by its own **impacting variables**:
buyer fit & timing, spec/tooling feasibility, FOB vs landed cost, MOQ, factory
reliability & quality, lead time, freight & **tariff/duty** (we hold HTS codes),
season alignment, competitor launches, price realization, returns, and turns.

**The inner loop — Crystal Ball.** Its entire job is one thing: **raise the
quality of the items we call out**, so more of them survive the outer loop and
the ones that do perform better.

**The connection that makes it compound.** The inner loop must be graded on
**outer-loop outcomes**, not on marketplace rank movement (that's only a proxy).
The real labels are: *Was it pitched? Did the buyer accept? Did it hit target
margin after sourcing? Did it sell through vs forecast? Did we reorder/variate?*
Every one of those already lives in our systems. Feed them back and Crystal Ball
gets a ground-truth report card every cycle — a **data flywheel** where call-out
quality compounds. That feedback path (§5A, F13–F16) is the single highest-
leverage upgrade in this plan.

```
     OUTER LOOP (commercial outcomes)  ──── labels ────┐
        pitched · accepted · margin · sold · reordered  │
                        ▲                                ▼
                        │                     INNER LOOP (Crystal Ball)
                        └──── better call-outs ◀──── learns from labels
```

Where each outcome is captured today:

| Outer-loop stage | Outcome signal | Source system |
|---|---|---|
| Pitched | item appears in a deck / offer / item-setup | Librarian |
| Buyer accepted | approval in emails / meeting notes / setup forms | Librarian (+ mail/notes) |
| Sourced & bought | PO raised, FOB/landed cost, MOQ, HTS/duty | `sqlmas90` |
| Sold through | units, velocity vs forecast, price realization | `shaundatabase`, `epocasql` |
| Reorder / variate | repeat/expanded PO | `sqlmas90` |

---

## 1. What "the loop" is today

The Crystal Ball loop is the multi-agent workflow described in the Sam's Club
partnership deck: *"AI that predicts winners before they trend."* Today it runs
roughly as:

```
external data (Amazon / Walmart / Five Below rankings, social, reviews)
        │
        ▼
  context engineering  ── RAG + prompt + state/memory + structured outputs
        │
        ▼
  feature extraction + customer-sentiment extraction
        │
        ▼
  curated "New & Now" product-highlight decks  (+ AI concept imagery)
        │
        ▼
  buyer roadmap  (price/pack guardrails, launch windows)
```

Outputs are dated PDF/deck snapshots (e.g. *Crystal Ball Sams Club Fall 2026*,
the cast-aluminum cookware proposal) framed around a consumer segment
("The Gleamers," sourced from WGSN) with a color-trend forecast and a
seasonal buyer roadmap.

### What the data lake actually holds (verified)

This is the key point: the raw material is far richer than the current output
exploits. Live row counts and coverage from `crystalball`:

| Signal | Table | Rows | Coverage | Cadence |
|---|---|---|---|---|
| Amazon rankings | `list_item` | **169.3 M** | Aug 2021 → today | **daily** |
| Walmart rankings | `wm_list_item` | 7.0 M | May 2025 → today | daily |
| Five Below rankings | `f_below_list_item` | 0.49 M | Oct 2024 → today | daily |
| Amazon search terms | `amz_search` | 6.8 M | rolling | **weekly**, ranked |
| Social posts | `sm_post` | 6.3 M | 2016 → today | continuous |
| Social engagement | `sm_user_engagement` | **177.7 M** | Apr 2023 → today | daily |
| Social post rank | `sm_post_rank` | 179.8 M | Apr 2023 → today | daily |

Each Amazon ranking row carries `cb_rank`, `cb_rating`, `cb_review_count`,
`cb_price`, and `cb_stamp` per product per day, across **1,329 lists / ~468 K
distinct products per quarter**. We also have internal ground truth in the
other schemas — `epocasql` (POS), `shaundatabase` (inventory & sell-through),
`sqlmas90` (invoices / POs), and `public` (brand data).

**The gap in one sentence:** we own a five-year, daily, SKU-level time series
plus internal sell-through, but the loop currently consumes it as if it were a
static "what's hot right now" snapshot.

---

## 2. Honest pros & cons of the current loop

### Pros — keep these
- **Buyer-native storytelling.** The Gleamers narrative, color palettes, and
  "mission focus" framing make the output land with merchants. Numbers alone
  don't sell to a buyer; this does.
- **Concrete, actionable end state.** It ends in SKU-level ideas, price/pack
  guardrails, launch windows, and concept imagery — not abstractions.
- **Sound architecture skeleton.** Multi-agent + RAG + structured outputs +
  memory is the right shape to build on. We are extending, not replacing.
- **Feature & sentiment extraction already conceived.** The pipeline already
  intends to read titles and reviews — we make it quantitative.
- **Credible framing.** HiPerGator compute + "2.2 M SKUs" gives external
  credibility to buyers.

### Cons — the things this plan fixes
1. **The time series is under-exploited.** The loop reports *what is already
   ranking*, not *what is accelerating*. That risks recommending items at or
   near their peak — the exact opposite of the stated "before they trend" promise.
2. **"6–12 months out" is asserted, not modeled.** There is no visible
   lead-lag or seasonality model that produces a dated forecast with a horizon.
3. **No feedback / backtest.** Predictions are not scored against what actually
   won, so we can't state a hit rate or tune the model. Without this, it isn't
   really a *loop* — it's a one-way report.
4. **Internal ground truth is disconnected.** POS / sell-through
   (`shaundatabase`, `epocasql`, `sqlmas90`) isn't fused in, so external buzz
   is never reconciled with what Epoca actually sells.
5. **Feature/benefit claims are anecdotal.** "No hot spots when searing" is a
   quote, not a measured lift. We can't yet say *which* features drive rank.
6. **Static, per-deck, manual.** Each report is hand-built for one retailer and
   one season instead of a living signal re-tailored on demand.
7. **Signals aren't chained.** Social → search → marketplace → sell-through is
   treated as separate slides, not as one leading-indicator cascade.

---

## 3. The unlock — what combining the three capabilities enables

| Capability | Role in the new loop | What it adds |
|---|---|---|
| **Crystal Ball SQL** | The *quant signal engine* | Velocity, acceleration, seasonality, lifecycle stage, feature lift — computed on 169 M+ rows |
| **Librarian** | The *memory + ground truth* | Past decks, buyer roadmaps, POS/sell-through, competitive specs, WGSN research already on file |
| **Fable research/analysis** | The *interpreter + forecaster* | Explains *why* a signal is moving, validates against the open web, and writes the causal narrative buyers trust |

Individually each is partial. Chained, they close the loop:
**measure (SQL) → explain & forecast (Fable + web) → reconcile to us (Librarian/POS)
→ recommend → record the prediction → score it next cycle → retune.**

---

## 4. Updated ideas (the concrete upgrades)

1. **Breakout Radar, not a bestseller list.** Rank every product/concept by
   *rank velocity + acceleration* instead of absolute rank. Surface pre-peak
   climbers. (Proven feasible — see §6.)
2. **Leading-indicator cascade.** Track the same concept across social
   engagement → Amazon search rank → marketplace rank → Epoca sell-through, and
   measure the *lag* between each stage. That lag is literally where the
   "6–12 months" number comes from — measured, not guessed.
3. **Seasonality-aware forecasting.** Decompose five years of daily data into
   trend + seasonal + noise, then project the trend and add the season back for
   the target window (e.g. Fall 2026). Output is a dated demand curve, not a bullet.
4. **Lifecycle-stage tagging.** Fit an S-curve (Bass/logistic) per concept and
   label it *Emerging / Growth / Peak / Decline*. Buy Emerging→Growth; flag
   Peak as "too late." Directly delivers the "don't buy what's already peaking" rule.
5. **Measured Feature & Benefit Lift.** Tokenize winning product titles + review
   sentiment; compute the average momentum of products *with* a feature (e.g.
   "PFAS-free," "detachable handle," "stackable") vs without. Ship a ranked
   feature leaderboard, not quotes.
6. **Whitespace detector.** Cross Crystal Ball demand against the retailer's
   current assortment (and Epoca's catalog) to find high-demand, low-supply gaps
   — the most valuable output for a private-label buyer.
7. **Prediction ledger + backtest.** Every recommendation is logged with a
   timestamp and horizon. Each cycle we score prior predictions against actual
   rank/sell-through movement and report a **hit rate** — the credibility engine.
8. **Living dashboard, re-tailored on demand.** The deck becomes a rendering of
   a continuously-updated model, filtered per retailer's roadmap guardrails
   automatically.
9. **Cross-retailer arbitrage.** A concept surging on Amazon but absent at
   Walmart / Five Below / Sam's is an early, low-risk pick — detectable because
   we hold all three marketplaces.
10. **Internal reconciliation.** Blend Epoca POS/sell-through as ground truth so
    a "trend" is only greenlit when it agrees with what we can actually source
    and move.
11. **Outcome-driven learning (the flywheel).** Grade every call-out by what it
    did in the outer loop — accepted? hit margin? sold? reordered? — and retrain
    the model on those labels so each cycle calls better items than the last.
    This is the core of "better and better results into the bigger loop" (§0, §5A).
12. **Margin-feasibility gate.** Predict achievable landed cost/margin from our
    own MRF/PO history *before* pitching, so we never spend buyer credibility on
    a trend we can't source to the price point.

## 5. The formulas (grounded in the actual variables)

Notation: for a product/concept *i* on day *t*, `r_{i,t}` = marketplace rank
(**lower = more popular**), `rev_{i,t}` = review count, `rat_{i,t}` = rating,
`p_{i,t}` = price. Because rank is compressed near the top, work in
`ρ = -ln(rank)` so a move from 80→40 and 40→20 count as equal momentum.

**F1 — Rank Velocity (momentum).** First derivative of log-rank.
```
V_i = ( ρ_{i, t}  -  ρ_{i, t-Δ} ) / Δ           where ρ = -ln(rank)
```
Positive V = climbing. (Simple average-rank form already demonstrated in §6.)

**F2 — Rank Acceleration.** Second derivative — separates a sustained breakout
from a one-week spike.
```
A_i = V_i(recent window)  -  V_i(prior window)
```
`A > 0 and V > 0` = accelerating breakout (the buy signal).

**F3 — Review Velocity (sales proxy).** Reviews accrue with units sold, so their
growth is the best in-dataset proxy for real sell-through.
```
RV_i = ( rev_{i,t} - rev_{i,t-Δ} ) / Δ        (optionally weight by rating trend)
```

**F4 — Search Demand Velocity (intent, leading).** From weekly `amz_search`
ranks for a feature/keyword term.
```
SDV_k = ρ_search_{k, w}  -  ρ_search_{k, w-1}
```

**F5 — Social Lead Signal (earliest).** Engagement growth on the concept's
hashtags/keywords from `sm_user_engagement` + `sm_post_rank`.
```
SL_c = Δ(views + α·likes + β·comments + γ·shares) / Δt   , per concept c
```

**F6 — Lead-Lag Lag Estimate (the horizon).** Cross-correlate the social series
against the review-velocity series across candidate lags; the lag τ* that
maximizes correlation is the concept's measured lead time.
```
τ*_c = argmax_τ  corr( SL_c(t) ,  RV_c(t + τ) )
```
Aggregating τ* across concepts calibrates the honest "typically N months out."

**F7 — Seasonality Decomposition + Forecast.** STL on 5-yr daily series per
concept/category → `trend + seasonal + resid`. Forecast for target window W:
```
D̂_c(W) = trend_projected(W)  +  seasonal_c(W)
```

**F8 — Lifecycle Stage.** Fit cumulative adoption to a logistic/Bass curve;
stage = position vs inflection point → {Emerging, Growth, Peak, Decline}.

**F9 — Feature/Benefit Lift.** For feature token f:
```
Lift_f = mean(Momentum | product has f)  -  mean(Momentum | product lacks f)
```
Rank features by Lift to produce the "features & benefits that are trending."

**F10 — Composite Predicted-Winner Score (PWS).** The single ranked output,
weights tuned by backtest (F11):
```
PWS_i =  w1·z(V_i) + w2·z(A_i) + w3·z(RV_i)
       + w4·z(SDV) + w5·z(SL)  + w6·SeasonalFit(W)
       + w7·LifecycleWeight
       - w8·Saturation/Competition
       - w9·PriceMismatchToGuardrail
```

**F11 — Backtest / Hit-Rate (closes the *inner* loop).** Freeze the model as of
`T − 12mo`, generate predictions, and measure **precision@K** and rank-gain of
predicted vs actual marketplace movement. This tunes the model against an
external proxy. But the *real* grading signal is the outer loop — see F13.

**F12 — Whitespace / Cross-Retailer Gap.**
```
Gap_c = PredictedDemand_c(W)  ×  (1 − AssortmentCoverage_c at target retailer)
```
High demand × low coverage = the priority pick.

---

## 5A. Outcome-driven learning — closing the *outer* loop

F1–F12 predict what *should* trend. F13–F16 grade Crystal Ball on what actually
happened commercially, and feed it back so call-out quality compounds (§0).

**F13 — Outcome-Weighted Item Quality Score (the training label).** For every
item we ever called out, roll its outer-loop journey into one score — this is
the ground-truth label `y` the model is trained to predict, replacing "did rank
go up" with "did it make money":
```
IQS_i =  a·Pitched_i          (0/1  — reached a deck/offer)
       + b·BuyerAccepted_i    (0/1  — approved)
       + c·MarginAchieved_i   (SRP − landed cost, vs target margin)
       + d·SellThroughRatio_i (actual units ÷ forecast units)
       + e·Reordered_i        (0/1/variate — the strongest winner signal)
```
Later, stronger stages get more weight (`a < b < c < d < e`). Partial credit
means even a buyer-rejected pick still teaches the model.

**F14 — Margin-Feasibility Prior (call it only if we can source it).** From
historical MRF/PO cost data (`sqlmas90`) + tariff/HTS + freight, predict the
achievable landed cost and margin for a concept *before* we pitch it. Filters
out ideas that trend but can't hit the retailer's price/pack guardrail —
stops us wasting buyer credibility on un-sourceable winners.
```
FeasibleMargin_c(W) = SRP_guardrail − f(historical FOB, MOQ, duty, freight)
```
Fold it into the PWS as a gate/penalty: `PWS' = PWS × 1[FeasibleMargin ≥ target]`.

**F15 — Forecast Calibration (learn our own conversion rate).** Map the model's
predicted demand (review-velocity / PWS) to *realized Epoca units* using past
sell-through (`shaundatabase`, `epocasql`). Re-fit each cycle so the unit
forecast that drives buy quantities gets more accurate over time (shrinking MAPE
= fewer overbuys/stockouts in the outer loop).

**F16 — Funnel Attribution (fix the leakiest stage).** Decompose why good
call-outs died — buyer pass vs margin fail vs sourcing vs sell-through miss — so
we know whether to improve *what we surface*, *how we price/spec it*, or *how we
pitch it*. Turns the loop's misses into targeted upstream fixes.

**Retraining.** Each cycle, regress the pre-launch feature vector
(V, A, RV, SDV, SL, seasonal fit, lifecycle, feature-lift tokens) against the
realized `IQS` (F13). The fitted coefficients become the next cycle's PWS
weights (F10) — so the system literally learns which signals predict *commercial*
winners for Epoca specifically, not just marketplace movement.

---

## 6. Proof of concept (already run against live data)

The core detector (F1) run on Amazon **Cookware Sets** — most-recent 14 days vs
a 6-weeks-prior window — with zero new infrastructure, surfaced clear pre-peak
climbers:

| Product (abbrev.) | Rank 6wk ago → now | Gain |
|---|---|---|
| Viking 3-Ply Stainless 11-pc | 44 → 7 | **+85%** |
| 24-pc Titanium-Reinforced Ceramic (PFAS-free) | 36 → 6 | **+84%** |
| Bazova 25-pc Titanium Ceramic (PFAS-free) | 33 → 12 | +63% |
| Calphalon Classic Stainless 10-pc | 73 → 29 | +61% |

Two things fall straight out of this, for free:
- The **climbers cluster on features** — *PFAS-free, ceramic, titanium-reinforced,
  detachable handle, induction, non-toxic* — which is exactly the F9 feature-lift
  signal waiting to be measured.
- It validates the cast-aluminum / PFAS-free thesis in the current cookware deck
  **with a live velocity number** instead of an assertion.

This is a fraction of one formula on one category. The full engine runs F1–F12
across every category, marketplace, and the social/search leading indicators.

---

## 7. Architecture of the improved loop

```
        ┌─────────────────────────────────────────────────────────┐
        │  1. SIGNAL ENGINE  (Crystal Ball SQL)                    │
        │     F1–F5 velocity/accel/review/search/social            │
        │     F7 seasonality · F8 lifecycle · F9 feature lift      │
        └───────────────────────────┬─────────────────────────────┘
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  2. FORECAST + INTERPRET  (Fable + web research)         │
        │     F6 lead-lag horizon · causal "why" · WGSN/web check  │
        └───────────────────────────┬─────────────────────────────┘
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  3. RECONCILE  (Librarian: POS, past decks, roadmap)    │
        │     internal sell-through ground truth · F12 whitespace  │
        └───────────────────────────┬─────────────────────────────┘
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  4. RANK + RECOMMEND     PWS (F10) → retailer-filtered   │
        │     SKU picks, feature specs, price/pack, launch window  │
        │     + concept imagery                                    │
        └───────────────────────────┬─────────────────────────────┘
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  5. PREDICTION LEDGER + OUTCOME FEEDBACK                 │
        │     F11 backtest (proxy) · F13 IQS from OUTER LOOP:      │
        │     pitched→accepted→margin→sold→reordered               │
        │     F14 margin prior · F15 forecast calib · F16 attrib   │
        └──────────────────────────────────────────────────────┘  │
                     ▲                                              │
                     └──── refits PWS weights back into 1 & 4 ─────┘
                     ▲
                     │  outer-loop results (sqlmas90 / shaundatabase / epocasql / Librarian)
```

Stage 5 is what makes it a **loop**. The inner backtest (F11) tunes against a
proxy; the outer-loop outcomes (F13–F16) tune against **money made**. Each cycle
grades the last one on real commercial results and refits the weights — quality
compounds.

---

## 8. Phased roadmap

**Phase 0 — Foundations (week 1)**
- Lock the category → `cb_list_id` / `cb_category_id` maps for Epoca's 7
  roadmap subcategories (cookware, gadgets, food storage, beverage dispensers,
  hydration, bakeware, candles).
- Build reusable SQL views for F1–F3 (velocity, acceleration, review velocity)
  parameterized by category and window.

**Phase 1 — Breakout Radar (weeks 2–3)**
- Ship F1/F2/F3 as a ranked "climbers" report per category and per marketplace.
- Add F12 cross-retailer gap. *Deliverable: replaces the static "New & Now"
  slide with a live, velocity-ranked one.*

**Phase 2 — Leading indicators & horizon (weeks 4–6)**
- Wire social (F5) and search (F4) signals; compute F6 lead-lag lags.
- Produce the first dated 6–12-month forecasts with a stated horizon.

**Phase 3 — Seasonality, lifecycle & feature lift (weeks 6–8)**
- F7 STL forecasting, F8 lifecycle staging, F9 feature-lift leaderboard.
- *Deliverable: "features & benefits trending into <season>" as measured lift.*

**Phase 4 — Reconcile & score, inner loop (weeks 8–10)**
- Fuse POS/sell-through via Librarian + foreign schemas.
- Stand up the F11 prediction ledger; run the first backtest and publish a
  hit rate. Tune PWS weights against the marketplace proxy.

**Phase 4B — Instrument the OUTER loop (weeks 10–13) — highest leverage**
- Build the prediction ledger that tracks every called-out item through
  pitched → accepted → MRF/margin → PO → sell-through → reorder, joining
  Librarian (decks/offers/setups) with `sqlmas90` (POs, cost, HTS/duty),
  `shaundatabase` + `epocasql` (sell-through).
- Compute F13 IQS labels; add F14 margin-feasibility gate; F15 forecast
  calibration; F16 funnel attribution.
- *Deliverable: retrain PWS on real commercial outcomes — the data flywheel
  turns on, and every future cycle inherits a smarter model.*

**Phase 5 — Productize the loop (ongoing)**
- Composite PWS (F10) as the one ranked output, auto-filtered per retailer
  roadmap and gated by margin feasibility; Fable writes the narrative; imagery
  generated per pick; ledger auto-scores each cycle against outer-loop results.

---

## 9. How we'll know it worked (success metrics)

- **Hit rate / precision@K** from the backtest (F11) — the headline number for
  buyers. Target: beat "pick current bestsellers" baseline by a clear margin.
- **Lead time** — median measured months between our flag and the marketplace
  peak (F6). Bigger = more actionable.
- **Whitespace conversion** — share of F12 gap picks that Epoca actually lists
  and that sell through.
- **Forecast error** — MAPE of F7 demand curves vs realized rank/review velocity.
- **Cycle latency** — time to re-tailor a full recommendation set for a new
  retailer/season (goal: minutes, from the living model, vs days of deck-building).

**Outer-loop (the metrics that actually pay):**
- **Buyer acceptance rate** of called-out items — trending up cycle over cycle.
- **Margin-hit rate** — share of accepted items that reached target margin after
  sourcing (proves F14 is filtering well).
- **Sell-through vs forecast** — realized units ÷ forecast (F15 calibration).
- **Reorder / variate rate** — the north star: share of called-out items that
  earned a second PO. This is "better and better results into the bigger loop"
  made measurable.
- **IQS trend** — average Item Quality Score (F13) of each cohort of call-outs,
  rising over time = the flywheel is compounding.

---

## 10. Risks & guardrails
- **Reviews ≠ perfect sales.** Review velocity is a proxy; always reconcile with
  POS before a final greenlight (Phase 4).
- **Rank compression / list churn.** Use log-rank (F1) and require minimum
  observation counts per window (already applied in §6) to avoid noise.
- **Category ID ambiguity.** The taxonomy repeats names across regions/parents
  (five "Cookware" nodes exist) — pin exact IDs in Phase 0.
- **Overfitting the backtest.** Hold out a validation window; prefer robust,
  interpretable weights over a maximally-tuned black box buyers won't trust.
- **Social noise / novelty spikes** ("Italian brain rot"): require the F6 lag
  and F8 lifecycle to agree before forecasting a durable trend.
```

*Next step:* stand up Phase 0 + Phase 1 SQL views so the very next Crystal Ball
deck ships with live velocity numbers instead of static snapshots.*
