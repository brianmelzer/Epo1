-- =====================================================================
-- 05_callout_outcomes.sql  —  Crystal Ball Loop 2.0, formula F13 (IQS)
-- Join the CALL-OUT LEDGER (../data/callout_ledger.csv) to real outcomes and
-- compute a first Item Quality Score per recommendation. THIS is the flywheel's
-- feedback step: predictions in, commercial outcomes out, model retrains.
--
-- The ledger lives as a CSV/sheet (the DB role is read-only). Paste its rows
-- into the VALUES block below (callout_id, match pattern, category). Validated
-- against shaundatabase on 2026-07-02.
--
-- MATCHING CAVEAT (validated): Epoca item descriptions use abbreviations
-- (CA = cast aluminum, CER = ceramic, SS = stainless, Ind = induction), so a
-- literal concept phrase can miss — e.g. '%meal prep%' matched 0 items. Two
-- fixes: (a) maintain a synonym map in the patterns below, and (b) once an
-- analyst fills linked_item_codes for a call-out, switch that row to an exact
-- item_code join for a precise, auditable outcome.
-- =====================================================================

WITH ledger(callout_id, concept, pat, target_margin) AS (VALUES
  -- callout_id, concept label, LOWER match pattern (synonym-aware), target margin %
  ('CB-2025-025','Cast aluminum PFAS-free cookware set', '% ca %',       35),
  ('CB-2025-015','10-piece silicone tool set',           '%silicone%',   30),
  ('CB-2025-010','Candle warmer lamp',                   '%warmer%',     40),
  ('CB-2025-012','Meat chopper',                         '%chopper%',    35),
  ('CB-2025-007','Stackable bakeware',                   '%bakeware%',   35),
  ('CB-2025-021','Magnetic spice organizer',             '%spice%',      35),
  ('CB-2025-019','Insulated beverage dispenser',         '%dispenser%',  30),
  ('CB-2025-013','Glass divided meal prep containers',   '%meal prep%',  30)  -- 0 matches: needs synonym/linked_item_codes
),
outcome AS (
  SELECT l.callout_id, l.concept, l.target_margin,
    count(DISTINCT h.item_code)                                            AS items_matched,
    count(DISTINCT h.yr || '-' || h.mth)                                  AS active_months,
    round(sum(h.shipped_qty))                                             AS units,
    round(sum(h.shipped_dollars))                                        AS gross,
    CASE WHEN sum(h.shipped_dollars) > 0
         THEN round(100*(sum(h.shipped_dollars)-sum(h.cogs))/sum(h.shipped_dollars))
         END                                                              AS margin_pct
  FROM ledger l
  LEFT JOIN shaundatabase.v_so_history h
    ON lower(h.item_code_desc) LIKE l.pat AND h.yr >= 2025 AND h.shipped_qty > 0
  GROUP BY l.callout_id, l.concept, l.target_margin
)
SELECT callout_id, concept, items_matched, active_months, units, gross, margin_pct,
  -- First-cut Item Quality Score (F13), 0..1. Tune weights against backtest.
  round((
      0.20 * least(coalesce(items_matched,0)::numeric / 3, 1)                     -- was it made/sold at all
    + 0.35 * least(coalesce(margin_pct,0)::numeric / NULLIF(target_margin,0), 1)  -- margin vs target
    + 0.25 * least(coalesce(units,0)::numeric / 50000, 1)                         -- volume (proxy for sell-through vs fcst)
    + 0.20 * least(coalesce(active_months,0)::numeric / 12, 1)                    -- persistence / reorder proxy
  )::numeric, 3) AS iqs
FROM outcome
ORDER BY iqs DESC NULLS LAST;
