-- =====================================================================
-- 09_concept_rollups.sql — concept-level signal rollups for Backtest v2
-- Consumes the concept graph bridges (data/concept_graph/*.csv). The DB is
-- read-only, so bridge rows are inlined as VALUES lists (paste from CSV) —
-- shown here with two-row stubs. Every rollup carries the bridge's
-- level_of_truth so v2 never silently promotes a category signal to a
-- product claim.
-- =====================================================================

-- ---- A. Concept rank series (product-level rollup) -----------------------
-- Daily average rank of a concept's member products (exact + accepted rule
-- edges only; filter bridge rows to match_confidence >= your floor).
WITH bridge(concept_id, cb_product_id) AS (
  VALUES ('CG-0006', 2001933), ('CG-0006', 1921275)  -- paste concept_product_bridge rows
)
SELECT b.concept_id, li.cb_stamp,
       avg(li.cb_rank)                AS concept_avg_rank,
       min(li.cb_rank)                AS concept_best_rank,
       count(DISTINCT li.cb_product_id) AS members_observed
FROM crystalball.list_item li
JOIN bridge b ON li.cb_product_id = b.cb_product_id
WHERE li.cb_stamp >= date '2024-01-01'   -- PARAM: window
GROUP BY 1, 2
ORDER BY 1, 2;

-- ---- B. Concept search-demand series (concept-level) ----------------------
-- Weekly average -ln(rank) of a concept's matched search terms. This is the
-- honest home for search signals: concept-level prediction, not product.
WITH bridge(concept_id, search_text) AS (
  VALUES ('CG-0006', 'oil sprayer for cooking'), ('CG-0006', 'olive oil sprayer')
)
SELECT b.concept_id, tp.cb_date_to AS week_ending,
       avg(-ln(s.cb_rank))          AS concept_search_intensity,
       count(DISTINCT s.cb_text)    AS terms_ranked
FROM crystalball.amz_search s
JOIN crystalball.amz_term_period tp ON tp.cb_period_id = s.cb_period_id
JOIN bridge b ON s.cb_text = b.search_text
GROUP BY 1, 2
ORDER BY 1, 2;

-- ---- C. Concept outcome rollup (units-based labels) -----------------------
-- Realized units/gross per concept via EXACT item_code edges only
-- (concept_epoca_sku_bridge rows with review_status=approved or
-- match_confidence >= 0.85 — never regex rows). Replaces description-regex
-- scoring in 06_ledger_refresh; enables units-based IQS labels and separates
-- concept-attributed gross from raw keyword-matched gross.
WITH bridge(concept_id, item_code) AS (
  VALUES ('CG-0001', 'EOI5-D2816'), ('CG-0001', 'EOI5-D4506')
)
SELECT b.concept_id,
       count(DISTINCT h.item_code)  AS items,
       sum(h.units)                 AS units,
       sum(h.gross)                 AS concept_attributed_gross
FROM shaundatabase.v_so_history h
JOIN bridge b ON h.item_code = b.item_code
WHERE h.month >= '2025-01'           -- PARAM: outcome window
GROUP BY 1;

-- ---- D. Double-count exposure check ---------------------------------------
-- Item codes claimed by more than one concept (should be empty after curation;
-- rows here = raw-gross double counting in the old regex scoring).
WITH bridge(concept_id, item_code) AS (
  VALUES ('CG-0001', 'EOI5-D2816'), ('CG-0018', 'EOI5-D2816')
)
SELECT item_code, count(DISTINCT concept_id) AS claimed_by,
       string_agg(DISTINCT concept_id, ';') AS concepts
FROM bridge
GROUP BY 1
HAVING count(DISTINCT concept_id) > 1;
