# Flywheel Automation — Call-Out Ledger Refresh Runbook

*How the Crystal Ball call-out ledger keeps itself scored so the prediction
model learns from real commercial outcomes each cycle. This operationalizes
§0 (two loops) and §5A / F13–F16 of
[`CRYSTAL_BALL_LOOP_V2.md`](CRYSTAL_BALL_LOOP_V2.md).*

All numbers below come from a live run of
[`../sql/06_ledger_refresh.sql`](../sql/06_ledger_refresh.sql) against
`shaundatabase.v_so_history` on **2026-07-02** (outcome window FY2025-01 →
2026-07-02). Nothing here is estimated.

---

## 1. What the refresh does

`06_ledger_refresh.sql` scores **all 26 call-outs** in
[`../data/callout_ledger.csv`](../data/callout_ledger.csv) in one pass and emits,
per call-out: `run_date, items_matched, active_months, units, gross, margin_pct,
iqs`. `iqs` is the F13 Item Quality Score (0–1) — the ground-truth training label
`y`. Those columns are written back into the ledger's outcome fields plus a new
`scored_asof` stamp, so the ledger is always current as of its last refresh.

**Baseline distribution (scored 2026-07-02), the reference for drift:**

| Metric | Value |
|---|---|
| Call-outs scored | 26 (24 matched, 2 zero-match) |
| Mean IQS (all 26) | **0.824** |
| Mean IQS (24 matched) | 0.893 |
| Median IQS | 1.000 |
| Share IQS < 0.5 | **15%** (4 of 26) |
| Zero-match concepts | CB-2025-006 (oil sprayer), CB-2025-013 (glass meal-prep) |

Note on saturation: 14 of 26 sit at IQS = 1.000 because the F13 caps
(units/50 000, margin/target) top out for high-volume cookware. That is fine for
a first pass but blunts discrimination — flagged as a re-tune item at first
retrain (§4).

---

## 2. Cadence

| Task | Cadence | Why |
|---|---|---|
| **Outcome refresh** (run `06`, update `iqs` + `scored_asof`) | **Monthly** | `v_so_history` rolls up by `yr`/`mth`; a month is the smallest unit where units/margin/active-months actually move. Cheap (one query), keeps IQS labels fresh between deck cycles. |
| **Drift check** (compare current vs baseline distribution) | **Monthly**, right after the refresh | Cheap; it's the trigger that decides whether a retrain is due. |
| **PWS retrain** (re-fit F10/F11 weights on IQS) | **Quarterly** *or* on a drift breach (§4) | Aligns with the seasonal deck cycle (Sam's Club Fall/Holiday/SS windows) and gives new call-outs ~1–2 quarters to accrue sell-through before they become training labels. Retraining faster than that just re-fits noise. |

Rationale: outcomes accrue slowly (a call-out needs months of ship history before
its IQS is meaningful), so scoring monthly but retraining quarterly matches the
signal's real update rate without overfitting.

---

## 3. Refresh steps (the monthly run)

1. **Anchor the window.** Set the `run_date` PARAM in `06_ledger_refresh.sql` to
   the latest complete data date (data as of). Today's validated anchor is
   `2026-07-02`.
2. **Run** `06_ledger_refresh.sql` via the read-only `Epoca-CrystalBall` SQL
   tool. It returns one row per `callout_id`.
3. **Write back.** For each returned row, update the matching ledger row's
   `realized_units` (=units), `realized_gross` (=gross), `margin_pct`, `iqs`,
   and set `scored_asof` = run_date. Set `reordered` from the persistence proxy:
   `yes` if `active_months >= 12`, `no` if 1–11, blank if 0 matches. Leave
   `linked_item_codes` for analyst curation (§6). Keep all other columns intact.
4. **Log drift.** Recompute mean IQS, median, and share-below-0.5 over the full
   ledger and over the newest cohort (call-outs from the most recent quarter).
   Append a one-line drift record (date, n, mean, median, share<0.5) — a
   `docs/` note or a `data/ledger_drift_log.csv` — and compare to §1 baseline.
5. **Decide retrain.** If the §4 rule fires, kick the quarterly retrain early.

---

## 4. RETRAIN trigger (the concrete rule)

Retrain the PWS weights when **either** holds, comparing the newest cohort
(call-outs from the most recent full quarter) against the trailing baseline
(§1, currently mean 0.824 / share<0.5 = 15%):

- **Mean shift:** `|mean_IQS(recent) − mean_IQS(baseline)| ≥ 0.15`, **or**
- **Tail shift:** `share(IQS < 0.5)` changes by `≥ 20` percentage points.

Also retrain **on schedule every quarter** regardless of drift, so the model
never goes more than one deck cycle without absorbing new outcomes.

**Mechanism (F10/F11 re-fit).** For every call-out with a settled IQS, assemble
its **pre-launch feature vector** — F1 rank velocity `V`, F2 acceleration `A`,
F3 review velocity `RV`, F4 search-demand velocity `SDV`, F5 social lead `SL`,
F7 seasonal fit, F8 lifecycle weight, F9 feature-lift tokens — computed as of the
call-out date. Regress that vector against the realized `iqs` (F13) label:

```
iqs_i  ~  w1·z(V) + w2·z(A) + w3·z(RV) + w4·z(SDV) + w5·z(SL)
        + w6·SeasonalFit + w7·LifecycleWeight − w8·Saturation − w9·PriceMismatch
```

Use ridge / regularized OLS (small n → keep it interpretable; hold out a
validation window per §10 of the strategy doc). The fitted coefficients become
the next cycle's PWS weights (F10). At the same retrain, re-tune the F13 caps
(units/50 000, margin/target) so the label spreads across 0–1 instead of
saturating at 1.000 (§1).

Inputs required: the scored ledger (this file's outputs) + the F1–F9 feature
snapshots from `01_breakout_radar.sql` / `02_feature_lift.sql` captured at
call-out time. Where a call-out predates feature capture, use the earliest
available snapshot and flag it lower-confidence.

---

## 5. Scheduling (documented — DO NOT enable without approval)

The environment exposes scheduled-routine tools (`create_trigger` /
`send_later`). **A live trigger is intentionally NOT created here** — the
coordinator/user approves turning it on. When approved, create it exactly as:

- **Recurrence (monthly refresh):** cron `0 9 2 * *` (09:00 on the 2nd of each
  month, after month-end data settles).
- **Recurrence (quarterly retrain reminder):** cron `0 9 5 1,4,7,10 *`.
- **Routine prompt (monthly):**

  > "Monthly Crystal Ball flywheel refresh. Set the `run_date` PARAM in
  > `sql/06_ledger_refresh.sql` to the latest complete data date, run it against
  > the read-only Epoca-CrystalBall SQL tool, and write the returned
  > `units/gross/margin_pct/iqs` plus `scored_asof` back into
  > `data/callout_ledger.csv` (reordered = yes if active_months>=12). Recompute
  > mean IQS / median / share-below-0.5 over the full ledger and the newest
  > cohort, append a drift log line, and compare to the baseline in
  > `docs/FLYWHEEL_AUTOMATION.md` §1. If the §4 retrain rule fires, open a note
  > flagging a PWS retrain. Do not git commit; report the diff."

- **Routine prompt (quarterly):** same as above plus "then run the F10/F11
  re-fit per §4 and propose new PWS weights."

**Manual fallback** (if automated scheduling isn't approved): a calendar
reminder on the 2nd of each month to run steps §3.1–§3.5 by hand. The query is a
single copy-paste, so the manual runbook is ~5 minutes.

---

## 6. Matching-quality note

Scoring today is **concept-level keyword/regex matching**, made synonym-aware
(CA = cast aluminum, CER = ceramic, SS = stainless, IND = induction) so more
concepts match against Epoca's abbreviated item descriptions. That closes most
of the gap seen in `05_callout_outcomes.sql` — but two concepts still return
**zero matches** because Epoca has no clean internal descriptor for them:

- **CB-2025-006 Oil sprayer** — no `oil spray/mist/dispenser` descriptions.
- **CB-2025-013 Glass divided meal prep containers** — `meal prep` still matches
  nothing (the same gap flagged in `05`); the food-storage line isn't described
  that way.

Two consequences of proxy matching to watch: broad synonym patterns can
**over-match** (e.g. the ceramic-bakeware concepts CB-2025-018/025 sweep in the
whole CA CER cookware book, inflating units/gross), and abbreviation-free
concepts **under-match** to zero.

**The fix that compounds:** curate `linked_item_codes` per call-out over time.
Once an analyst pins the exact `item_code`s a call-out became, switch that row
from the regex proxy to an exact `item_code` join — precise, auditable, and
immune to both over- and under-matching. Each cycle a few more rows get curated,
so ledger accuracy improves monotonically and the F13 labels the model trains on
get cleaner. This is the human-in-the-loop half of the flywheel.
