# Crystal Ball — Handoff & Onboarding

You're inheriting a working, honest, self-improving product-intelligence system
for Epoca (kitchen/home goods supplier to Sam's Club, Walmart, etc.). This file
is the single starting point. Companions: `docs/TOP_QUESTIONS_TO_FIX.md` (known
problems, ranked) and `docs/NEXT_STEPS.md` (the build queue).

## What this is, in one paragraph

Crystal Ball predicts which specific products Epoca should make and pitch to
retail buyers. It runs **two nested loops**: an **inner prediction loop** (SQL
signals over a 169M-row daily Amazon ranking time series + Walmart/Five
Below/search/social) and an **outer commercial loop** (call-out → buyer pitch →
MRF → factory/PO → ship → sell-through → reorder). The inner loop is graded on
the outer loop's real money via a scored **call-out ledger** (IQS, 0–1), so
recommendation quality compounds. Everything is evidence-first: claims are
backtested, weak signals are labeled, and one signal (pure rank velocity) has
been formally **falsified** — don't resurrect it.

## Map of the repo

| Path | What it is |
|---|---|
| `docs/CRYSTAL_BALL_LOOP_V2.md` | The strategy: two loops, formulas F1–F16, roadmap. Read first. |
| `docs/PLATFORM_ARCHITECTURE.md` | Multi-agent platform blueprint (PR #7). |
| `docs/BACKTEST_V0.md` + `sql/07` | The honesty engine: frozen thresholds (P@10>6.5%, median Δρ<−0.192, survival>66%). Never retune after seeing results. |
| `docs/BACKTEST_V1_RESULTS.md` + `sql/08` | Multi-source composite test. Verdict: composite **ties** baseline on P@10; buys downside protection. Review-growth + commercial filters are the real signals; search is concept-level; social is category heat; **velocity falsified**. |
| `docs/BACKTEST_V1_DATA_INVENTORY.md` | Every data source classified: backtestable-now / live-only / needs-capture. |
| `sql/01–06, 09, 10` | The production query pack (radar now ranks on validated PWS_v1; spec-cell extractor; ledger scorer). All parameterized, all validated live. `sql/README.md` = conventions + category→ID map. |
| `data/callout_ledger.csv` | **The crown jewel.** 34 scored call-outs with outcomes (units/gross/margin/reorder/IQS) + buyer-ask fields. The flywheel's training labels. |
| `docs/FLYWHEEL_AUTOMATION.md` + `.github/workflows/flywheel-weekly.yml` + `scripts/flywheel_refresh.py` | Weekly re-scoring automation (blocked on DB secret — see questions doc). |
| `docs/SPEC_CELLS_ALL_CATEGORIES.md` | Profit-weighted spec-cell calls across 7 categories. Best call: **12-pc ceramic-coated glass food storage, PFAS-free, $69–99** (empty $50–125 shelf). |
| `docs/BUYER_ASK_PLAYBOOK.md` | 8 ready-to-say buyer asks + the pitch-outcome capture rule. |
| `docs/SCENARIO_SIMULATION_LAYER.md` | PR #9 blueprint (buyer-agent simulation, design-only, backtest-gated). |
| `docs/crystal-ball-*.html` | Dashboard + 8 category decks. **Internal-only** — served as private Claude artifacts, scrubbed from the public site. |

## Data access

Read-only SQL over `epocadatalake` via the **Epoca-CrystalBall** MCP tool.
Five schemas: `crystalball` (rankings/search/social), `shaundatabase`
(inventory/sales — foreign, slow, filter tight), `sqlmas90` (POs/invoices),
`epocasql` (POS), `public`. Conventions: lowercase snake_case, no quotes,
schema-qualify, `cb_` column prefix in crystalball, **lower rank = more
popular** (work in ρ = −ln(rank)). Queries die at ~60s — use MATERIALIZED CTE
hints and staged extraction (see `sql/08`/`sql/10` headers). Social tables are
PK-indexed only — unbounded scans wedge the connection.

## Hard-won rules (do not relearn these the expensive way)

1. **Never rank on raw velocity.** Falsified: 1/200 top-10 winners. It's a
   watch column only.
2. **Freeze backtest thresholds before looking at results.** The v0 numbers are
   the permanent bar.
3. **Spec-level beats category-level.** "30-pc glass, snap lids, $39" is a
   sale; "glass food storage" is a slide.
4. **Regex concept-matching over-matches** (CA/CER sweeps whole books) and
   under-matches (0-match rows). Curating `linked_item_codes` per ledger row is
   the permanent fix; do a few each week.
5. **State weak signals plainly.** The honest caveat culture is why buyers can
   trust the numbers — decks explicitly label thin data, provisional windows,
   review-merge artifacts, and anti-calls.
6. **Internal data never goes to the public site.** Pages deploy is scrubbed
   (`pages.yml`); dashboards live as private Claude artifacts.

## Cadence

Weekly: run `sql/06` (or `scripts/flywheel_refresh.py`), update ledger + drift
log. Quarterly (or on drift breach ≥0.15 mean / ≥20pt tail): re-fit PWS weights
against realized IQS. Every deck cycle: regenerate decks from the SQL pack,
ship asks, log pitch outcomes within a week.
