# Next Steps — the Build Queue

Ordered. Each step says what, why, and its done-condition. Steps 1–3 are
process (days); 4–7 are builds (weeks); 8–9 are the horizon.

## 1. Turn the flywheel on unattended (days, mostly IT)
Get `EPOCA_DATABASE_URL` + network path from IT (see
`docs/TOP_QUESTIONS_TO_FIX.md #1`), run the Actions workflow once manually,
confirm it commits a ledger refresh + drift-log line.
**Done when:** two consecutive Mondays commit automatically.

## 2. Start logging pitch outcomes (days, sales process)
Ship the 8 ask lines from `docs/BUYER_ASK_PLAYBOOK.md` into real buyer
meetings; log `pitch_date`/`pitch_outcome`/`buyer_accepted` within a week.
**Done when:** ≥10 rows have outcomes and acceptance-rate appears on the
dashboard.

## 3. Curate linked_item_codes (30 min/week, analyst)
Pin exact item_codes for the top 10 ledger rows; fix the two zero-match rows
and the two over-match rows first.
**Done when:** ≥50% of realized gross flows through exact joins, not regex.

## 4. Start Group-3 data capture (1–2 weeks, then passive)
Weekly jobs per the schemas in `docs/BACKTEST_V1_DATA_INVENTORY.md`: Google
Trends, Reddit, Pinterest, editorial mentions, attribute snapshots — aligned to
`amz_term_period` weeks. This is the fuel Backtest v2 needs.
**Done when:** 4+ weeks of captures exist for ≥3 new sources.

## 5. PR #9 — the simulation thin slice (2–3 weeks)
Per `docs/SCENARIO_SIMULATION_LAYER.md`: build ONLY the 4 buyer agents +
Skeptic (temperature-0, evidence-grounded, advisory-only), run them
retrospectively against the 34 ledger call-outs under no-look-ahead
discipline. **Go/no-go is pre-registered:** sim-adjusted picks must beat
baseline on the frozen v0/v1 metrics or the layer is deleted. Grade simulated
buyer objections against real ones (from pitches logged in step 2).
**Done when:** the comparison table exists and the go/no-go verdict is written.

## 6. Quarterly retrain #1 (after ~a quarter of steps 1–3)
Re-fit PWS weights against realized IQS (mechanism in
`docs/FLYWHEEL_AUTOMATION.md §4`); re-tune the saturating F13 caps at the same
time. **Done when:** new weights are committed with the train/holdout split
documented, and the radar (`sql/01`) cites the new version.

## 7. Spec cells v2 (1–2 weeks)
Improve title-parse coverage (better regexes or LLM pass), add review-complaint
mining on each hot cell's leaders ("their item + the fix"), and feed winning
cells directly into new ledger call-outs each cycle.
**Done when:** parse coverage >75% on top-100 products and each deck's pick
cites a cell + a complaint-fix.

## 8. Backtest v2 (once step 4 has ~a quarter of data)
Re-run the strategy/ablation harness (`sql/08`) with product-level search
attribution, post→product linkage, and units-based labels from the ledger.
Same frozen thresholds. **Done when:** the honest verdict is published,
whichever way it goes.

## 9. Platform build-out (background)
Follow `docs/PLATFORM_ARCHITECTURE.md` Phase 1: productize what exists
(Concept Graph entity resolution first — the ledger's zero-match rows are the
proof it's needed). Adopt infrastructure only on the blueprint's explicit
triggers, not upfront.

## Working agreements (carry these forward)
- Draft PRs, merged only after the checks in each doc's done-condition.
- Every number in a deck comes from a query that actually ran; weak signals
  labeled, never inflated.
- The backtest thresholds are frozen; new claims get new pre-registered tests.
- Internal data stays off the public web (artifacts + scrubbed deploy).
