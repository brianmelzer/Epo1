# Top Questions to Fix

Ranked by impact. Each has the question, why it matters, and where to start.

## 1. Can the weekly flywheel reach the database unattended?
The GitHub Actions cron (`flywheel-weekly.yml`) needs repo secret
`EPOCA_DATABASE_URL` (format:
`postgresql://agent_readonly:<PW>@<AURORA-ENDPOINT>:5432/epocadatalake?sslmode=require`).
The DB resolves to a private VPC IP (172.31.x.x), so GitHub cloud runners
likely can't reach it — needs a self-hosted runner inside Epoca's network or an
allowlisted endpoint. **Owner: IT** (an ask email exists; see session history /
resend from `docs/FLYWHEEL_AUTOMATION.md §5`). Until fixed, refresh manually.

## 2. Are buyers actually saying yes? (the dark funnel stage)
`buyer_accepted`, `pitch_date`, `pitch_outcome` in the ledger are empty. This
is the single missing F13 label and where F16 says picks die. Fix = process,
not code: every pitch logged within a week per `docs/BUYER_ASK_PLAYBOOK.md`.
10 filled rows make acceptance rate a real KPI.

## 3. Which items did each call-out actually become?
Concept→item matching is regex; 2 rows match nothing (oil sprayer, glass
meal-prep) and broad patterns over-match (CB-2025-018/025 sweep the whole
CA CER book — their $38–43M gross is inflated). Curate `linked_item_codes` for
the top ~10 rows (30 min of analyst work), then `sql/06` switches those rows to
exact joins automatically.

## 4. Why do 14 of 34 IQS scores saturate at 1.000?
The F13 caps (units/50,000, margin/target) top out for high-volume items,
blunting discrimination. Re-tune caps at the first quarterly retrain so labels
spread across 0–1. Don't change mid-cycle — do it at a declared retrain.

## 5. Can we get product-level search & social attribution?
Backtest v1's ceiling was data, not math: search is rank-only (no query
volume, no click/purchase attribution) and social posts aren't linked to
products. The capture pipelines are specced in
`docs/BACKTEST_V1_DATA_INVENTORY.md` (Group 3: Google Trends, Reddit,
Pinterest, editorial, attribute snapshots). Every uncaptured week is a week
Backtest v2 can't use — start the weekly capture jobs.

## 6. Does the spec-title parser miss too much?
Parse coverage is 43–65% (singles omit piece counts; "50 Pack (100-Piece)"
ambiguity; category contamination like juice bottles in food storage). Improve
regexes or add an LLM extraction pass for the top-100 per category; re-check
against the documented misses in `docs/SPEC_LEVEL_BREAKOUT_FOODSTORAGE.md`.

## 7. Is the composite actually worth using? (keep testing)
Backtest v1: composite ties baseline P@10 (6.5%), wins on survival (+21/200).
Honest open question: does downside protection compound into more profit per
200 picks? Track it forward via the ledger rather than re-arguing the backtest.

## 8. Repo/artifact access hygiene
Is the repo private? (If public, internal files are still readable there.)
Pages should stay unpublished (Settings → Pages) — the deploy now ships a
blank page. Deck artifacts are private; share each to the Claude Team
alongside the dashboard or teammates hit permission walls.

## 9. MOQ/cost assumptions in the buyer asks
The 8 ask lines carry assumed MOQs (2.5k–10k) and F14-style margin targets.
Validate against real quotes (`shaundatabase.interskyquote`, `sqlmas90` POs)
before a buyer meeting.

## 10. Trigger/scheduling permissions in Claude sessions
MCP scheduled triggers (`create_trigger`/`send_later`) fail on an approval
gate in web-started sessions. Workaround exists (GitHub Actions). If in-session
scheduling matters, create Routines from the claude.ai UI directly.
