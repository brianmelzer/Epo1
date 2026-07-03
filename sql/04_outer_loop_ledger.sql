-- =====================================================================
-- 04_outer_loop_ledger.sql  —  Crystal Ball Loop 2.0, formulas F13–F15
-- The FLYWHEEL: grade items on real OUTER-LOOP outcomes (sell-through, margin,
-- reorder) so the inner prediction model can be retrained on what made money.
--
-- All three parts validated against shaundatabase on 2026-07-02 (foreign tables:
-- keep filters tight; these views already denormalize Sage + POS + PO data).
--
-- Part A — Item Quality Score inputs (sell-through + margin + persistence)
-- Part B — Crystal Ball -> internal BRIDGE (asinxref) : link a ranked ASIN to
--          its own internal sell-through
-- Part C — Sale -> sourcing-PO margin (realized margin vs the PO that made it)
-- =====================================================================


-- ---------------------------------------------------------------------
-- PART A — IQS INPUTS: outcome scoring per item (F13)
-- active_months is a reorder/persistence proxy; margin_pct is realized margin.
-- Validated: Pioneer Woman CA griddle = 129,774 units / $2.7M / 41% / 18 months.
-- ---------------------------------------------------------------------
SELECT h.item_code, left(h.item_code_desc, 38) AS descr, h.sub_brand,
  count(DISTINCT h.yr || '-' || h.mth)  AS active_months,          -- persistence / reorder proxy
  round(sum(h.shipped_qty))             AS units_shipped,          -- volume (F15 input)
  round(sum(h.shipped_dollars))         AS gross_dollars,
  round(sum(h.cogs))                    AS cogs,
  CASE WHEN sum(h.shipped_dollars) > 0
       THEN round(100*(sum(h.shipped_dollars)-sum(h.cogs))/sum(h.shipped_dollars))
       END                              AS margin_pct              -- MarginAchieved (F13)
FROM shaundatabase.v_so_history h
WHERE h.class = 'COOKWARE'          -- PARAM: class/category
  AND h.yr >= 2025                  -- PARAM: window
  AND h.shipped_qty > 0
GROUP BY h.item_code, h.item_code_desc, h.sub_brand
HAVING sum(h.shipped_qty) > 0
ORDER BY gross_dollars DESC
LIMIT 20;
-- A first IQS can be assembled as, e.g.:
--   IQS = 0.15*[sold>0] + 0.35*min(margin_pct/target,1) + 0.30*[units vs forecast]
--         + 0.20*[active_months >= reorder_threshold]
-- then used as the training label y that F10's PWS weights are re-fit against.


-- ---------------------------------------------------------------------
-- PART B — BRIDGE Crystal Ball ranking  ->  internal sell-through (F13/F15)
-- asinxref links cb_asin to item_code. Validated: 516 xref rows, 220 ASINs
-- matched to Crystal Ball, 123 bridged items with 2025 sales. This closes the
-- loop for Epoca's OWN Amazon-listed items: external rank vs realized outcome.
-- ---------------------------------------------------------------------
SELECT x.asin, x.item_code, left(m.item_code_desc, 34) AS descr,
  ap.cb_first_ranking                                          AS first_ranked_on_amazon,
  round(sum(h.shipped_qty))                                    AS units_2025plus,
  round(sum(h.shipped_dollars))                               AS gross_2025plus,
  CASE WHEN sum(h.shipped_dollars) > 0
       THEN round(100*(sum(h.shipped_dollars)-sum(h.cogs))/sum(h.shipped_dollars))
       END                                                     AS margin_pct
FROM shaundatabase.asinxref x
JOIN crystalball.amz_product   ap ON ap.cb_asin = x.asin
JOIN shaundatabase.v_so_history h ON h.item_code = x.item_code AND h.yr >= 2025 AND h.shipped_qty > 0
LEFT JOIN shaundatabase.v_item_master m ON m.item_code = x.item_code
GROUP BY x.asin, x.item_code, m.item_code_desc, ap.cb_first_ranking
ORDER BY gross_2025plus DESC
LIMIT 20;
-- Extend: join crystalball.list_item on ap.cb_product_id to add rank VELOCITY
-- (formula F1) alongside realized sell-through -> the direct predictor-vs-outcome
-- table the backtest (F11) and calibration (F15) consume.


-- ---------------------------------------------------------------------
-- PART C — REALIZED MARGIN vs the sourcing PO (F14 ground truth)
-- v_invoiceddi_pivot joins each shipped sale to the PO that sourced it.
-- NOTE: po_unit_cost is TEXT with a '$' prefix -> strip before casting.
-- Validated 2026: PH Laptop Bag sold $16.61 vs PO $7.50 = 55% margin.
-- ---------------------------------------------------------------------
SELECT item_code, left(item_code_desc, 34) AS descr,
  round(sum(quantity_shipped))                                                   AS units,
  round(sum(quantity_shipped * unit_price))                                      AS sales,
  round(sum(quantity_shipped * replace(po_unit_cost, '$', '')::numeric))         AS po_cost,
  CASE WHEN sum(quantity_shipped * unit_price) > 0
       THEN round(100*(sum(quantity_shipped*unit_price)
                     - sum(quantity_shipped*replace(po_unit_cost,'$','')::numeric))
                  / sum(quantity_shipped*unit_price))
       END                                                                       AS margin_pct_vs_po
FROM shaundatabase.v_invoiceddi_pivot
WHERE yr = 2026                       -- PARAM: sale->PO link is densest 2026+
  AND quantity_shipped > 0
  AND po_unit_cost ~ '^\$?[0-9.]+$'   -- guard malformed cost strings
GROUP BY item_code, item_code_desc
ORDER BY sales DESC
LIMIT 20;
