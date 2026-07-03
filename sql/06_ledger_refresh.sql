-- =====================================================================
-- 06_ledger_refresh.sql  —  Crystal Ball Loop 2.0, formula F13 (IQS)
-- THE FLYWHEEL REFRESH PASS. Scores ALL 34 call-outs in
-- ../data/callout_ledger.csv (26 historical 2025 seeds + 8 forward-looking
-- 2026 deck picks) against real outer-loop outcomes in ONE query,
-- shaped ready to write straight back into the ledger's outcome columns:
--   callout_id, run_date, items_matched, active_months, units, gross,
--   margin_pct, iqs
--
-- Run this on the refresh cadence (see ../docs/FLYWHEEL_AUTOMATION.md), then
-- append/update iqs + scored_asof (+ realized_units/gross/margin) per row.
--
-- Reuses the F13 IQS weighting and the keyword-match approach from
-- 05_callout_outcomes.sql, extended to all 26 rows and made SYNONYM-AWARE:
-- Epoca descriptions abbreviate (CA = cast aluminum, CER = ceramic,
-- SS = stainless, IND = induction), so patterns are POSIX regex (~) with
-- word-boundary alternations (\yca\y, \yca cer\y) instead of a single LIKE,
-- which lets more concepts match. Patterns are built from each ledger row's
-- match_keywords / concept.
--
-- VALIDATED against shaundatabase.v_so_history on 2026-07-02 (data window:
-- FY2025-01 .. 2026-07-02). All 26 rows return; 24 match, 2 miss (CB-2025-006
-- oil sprayer, CB-2025-013 glass meal-prep — see matching-quality note in the
-- runbook). Foreign-table view: filters kept tight (yr >= 2025, shipped_qty>0).
--
-- MATCHING CAVEAT: keyword/regex matching is a concept-level proxy. Once an
-- analyst curates linked_item_codes for a call-out, switch that row to an exact
-- item_code join for a precise, auditable outcome.
-- =====================================================================

WITH ledger(callout_id, concept, pat, target_margin, since_yr) AS (VALUES
  -- callout_id, concept label, LOWER regex pattern (synonym-aware), target margin %,
  -- since_yr = outcome-window START. Historical 2025 seeds score FY2025+;
  -- forward-looking 2026 picks score FY2026+ ONLY, so a new call-out never
  -- inherits credit for items sold before it was made. (Exact-item curation via
  -- linked_item_codes remains the precise fix.)
  ('CB-2025-001','Cast aluminum cookware set',                 'cast al|\yca cer\y|\yca\y',            35, 2025),
  ('CB-2025-002','Motivational water bottle',                  'water bottle|motivational',            30, 2025),
  ('CB-2025-003','Magnetic charcuterie / serving set',         'charcuterie|serving|serveware',        35, 2025),
  ('CB-2025-004','Ice maker tumbler with snack tray',          'tumbler|snack tray',                   30, 2025),
  ('CB-2025-005','Towel warmer',                               'towel warmer',                         35, 2025),
  ('CB-2025-006','Oil sprayer',                                'oil spray|oil mist|oil dispenser',     35, 2025),  -- 0 matches
  ('CB-2025-007','Stackable bakeware',                         'bakeware',                             35, 2025),
  ('CB-2025-008','Air fryer liners',                           'fryer liner|air fryer liner',          35, 2025),
  ('CB-2025-009','Stainless steel electric lunch box',         'lunch box|lunch warmer|electric lunch',30, 2025),
  ('CB-2025-010','Candle warmer lamp',                         'candle warmer|warmer lamp|\ywarmer\y', 40, 2025),
  ('CB-2025-011','Instant read thermometer',                   'thermometer',                          35, 2025),
  ('CB-2025-012','Meat chopper',                               'chopper',                              35, 2025),
  ('CB-2025-013','Glass divided meal prep containers',         'meal prep|divided contain',            30, 2025),  -- 0 matches
  ('CB-2025-014','Glass nested food storage w/ bamboo lids',   'bamboo|food storage',                  30, 2025),
  ('CB-2025-015','10-piece silicone tool set',                 'silicone',                             30, 2025),
  ('CB-2025-016','360 rotating fridge storage rack',           'lazy susan|rotating|turntable|fridge', 35, 2025),
  ('CB-2025-017','Enameled cast iron bread baker',             'cast iron|enamel|dutch oven|bread',    35, 2025),
  ('CB-2025-018','Modular stackable ceramic bakeware',         'ceramic|\ycer\y|bakeware',             35, 2025),
  ('CB-2025-019','Double-walled insulated beverage dispenser', 'dispenser|beverage disp',              30, 2025),
  ('CB-2025-020','Non-toxic cast aluminum cookware',           'cast al|\yca cer\y|\yca\y',            35, 2025),
  ('CB-2025-021','Magnetic spice organizer',                   'spice',                                35, 2025),
  ('CB-2025-022','Lamp warmer',                                'candle warmer|warmer lamp|\ywarmer\y', 40, 2025),
  ('CB-2025-023','Stackable air fryer',                        'air fryer',                            35, 2025),
  ('CB-2025-024','Nesting mixing bowls in color',              'mixing bowl|nesting bowl',             35, 2025),
  ('CB-2025-025','11pc cast aluminum PFAS-free ceramic CWS',   'cast al|\yca cer\y|ceramic|\ycer\y|\yca\y', 35, 2025),
  ('CB-2025-026','Glass double-jar beverage station',          'dispenser|beverage|drink station',     30, 2025),
  -- ---- Forward-looking 2026 picks from the category decks (score FY2026+ only) ----
  ('CB-2026-027','CA PFAS-free ceramic set w/ detachable handle','cast al|\yca cer\y|detachable',           35, 2026),
  ('CB-2026-028','2pk leak-proof BPA-free divided bento',        'bento|leak.?proof|borosilicate|divided',  30, 2026),
  ('CB-2026-029','3pc ceramic baker + roaster w/ cooling rack',  'ceramic bak|roaster|cooling rack',        35, 2026),
  ('CB-2026-030','Elements 6pc stainless non-slip gadget set',   'stainless.*(gadget|tool)|non.?slip|shredder|\yscale\y', 30, 2026),
  ('CB-2026-031','PH soy candle gift set + warmer-lamp attach',  'soy candle|candle warmer|warmer lamp',    40, 2026),
  ('CB-2026-032','Primula DW stainless insulated 2pk gift set',  'double.?wall|insulated.*(mug|tumbler)',   30, 2026),
  ('CB-2026-033','Value tri-ply 10pc step-up SKU',               'tri.?ply|3.?ply|3ply',                    35, 2026),
  ('CB-2026-034','CL magnetic charcuterie board w/ det. handle', 'charcuterie|serving board|cheese board',  35, 2026)
),
outcome AS (
  SELECT l.callout_id, l.concept, l.target_margin,
    count(DISTINCT h.item_code)                         AS items_matched,
    count(DISTINCT h.yr || '-' || h.mth)               AS active_months,   -- persistence / reorder proxy
    round(sum(h.shipped_qty))                          AS units,
    round(sum(h.shipped_dollars))                      AS gross,
    CASE WHEN sum(h.shipped_dollars) > 0
         THEN round(100*(sum(h.shipped_dollars)-sum(h.cogs))/sum(h.shipped_dollars))
         END                                           AS margin_pct       -- realized margin (F13)
  FROM ledger l
  LEFT JOIN shaundatabase.v_so_history h
    ON lower(h.item_code_desc) ~ l.pat            -- PARAM: synonym-aware match
   AND h.yr >= l.since_yr                         -- per-row outcome window (2025 seeds / 2026 picks)
   AND h.shipped_qty > 0
  GROUP BY l.callout_id, l.concept, l.target_margin
)
SELECT callout_id,
  date '2026-07-02' AS run_date,                 -- PARAM: refresh anchor (data as of)
  items_matched, active_months, units, gross, margin_pct,
  -- F13 Item Quality Score (0..1) — same weighting as 05_callout_outcomes.sql.
  round((
      0.20 * least(coalesce(items_matched,0)::numeric / 3, 1)                     -- made/sold at all
    + 0.35 * least(coalesce(margin_pct,0)::numeric / NULLIF(target_margin,0), 1)  -- margin vs target
    + 0.25 * least(coalesce(units,0)::numeric / 50000, 1)                         -- volume (sell-through proxy)
    + 0.20 * least(coalesce(active_months,0)::numeric / 12, 1)                    -- persistence / reorder proxy
  )::numeric, 3) AS iqs
FROM outcome
ORDER BY callout_id;
