# Recursive Learning Plan

*How Crystal Ball learns from itself at four nested speeds. Companion to
COMMAND_DECK_HANDOFF.md (build contract) and NEXT_STEPS.md.*

## Dashboard review (2026-07-17)
Works: action-first live top-10s ranked by the backtest-validated PWS_v1,
rows clickable to real products, methodology one tab away, honest empty
states. Weak: (1) snapshot-not-live — rows freeze at last redeploy; (2) no
act-from-the-row affordance (Command Deck composer fixes); (3) no per-row
confidence (needs prediction ledger); (4) no week-over-week delta memory.

## Data access review
- epocadatalake: 169M daily Amazon rank rows (2021→, incl. New Releases),
  296+ weekly search periods (2020→), ~350M social rows (2023→), Walmart/
  Five Below, internal sell-through/PO/POS/quotes. Gaps per Backtest v1:
  no query volume, no click/purchase attribution, no post→product link,
  predictions overwritten each run.
- NEW connectors that close those gaps: **Skai** (search terms with clicks +
  conversions = the missing product-level attribution), **Outlook/Gmail +
  Granola** (buyer emails + meeting transcripts = pitch outcomes/objections),
  **Brandfolder** (item→asset), **Smartsheet/Todoist** (MRF workflow),
  **Librarian** (retrospective labels from past decks/quotes).

## The four recursion speeds
1. **Weekly facts** — flywheel re-scores call-outs vs sell-through → IQS +
   drift log. Exists; blocked on EPOCA_DATABASE_URL/network only.
2. **Weekly predictions** — archive every AmzSearchPrediction /
   HashtagPrediction run into `crystalball.prediction_ledger` BEFORE the app
   overwrites it; score at 12/26-week horizon → hit rate per concept class →
   the per-row confidence (`85% · 6`).
3. **Continuous human outcomes** — composer sends + a weekly Outlook/Granola
   harvest fill pitch_date/pitch_outcome/buyer_accepted + objections →
   acceptance rate becomes a label; PR #9 sim objections graded vs real.
4. **Quarterly model** — re-fit PWS weights on accrued IQS + hit rates under
   the frozen-threshold protocol; each Backtest vN adds newly captured
   signals (Skai attribution first). Drift log decides when retrain fires.

Compounding: better weights → better call-outs → more pitches → more labels
→ better weights. Only the pitch itself needs a human.

## Plan
- **Phase 0 (now):** DB secret + network path → unattended weekly flywheel.
  Ship the prediction-ledger archive job FIRST (history accrues from day 1).
- **Phase 1 (wk 1–3):** Skai weekly search→click/conversion extract aligned
  to amz_term_period weeks; Outlook/Granola pitch-outcome harvest agent.
- **Phase 2 (wk 3–6):** first horizon scoring → confidence on every
  dashboard/Command Deck row; first quarterly PWS retrain.
- **Phase 3 (wk 6–10):** Command Deck composer (send = ledger write); PR #9
  buyer-agent slice graded against real objections.
- **Phase 4 (quarterly, forever):** Backtest vN with new signals, frozen
  thresholds, honest verdict, retrain, repeat.
