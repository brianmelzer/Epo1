-- =====================================================================
-- 10_backtest_v2_concept_leadlag.sql — Backtest v2.0 concept-level analyses
-- Two queries, both consuming Concept Graph v0 bridges (rows inlined from
-- data/concept_graph/*.csv as of build 2026-07-05). Results and reading:
-- ../docs/BACKTEST_V2.md. Validated live 2026-07-05.
--
-- CAVEAT: concept membership is as-of the graph build date -> these are
-- pseudo-out-of-sample measurements (bias inflates lead-lag; the null
-- result survives it).
-- =====================================================================

-- ---- 1. Search-vs-rank lead-lag at concept level ---------------------------
-- Weekly Δ(search intensity) vs Δ(rank intensity) correlated at lags -4..+12
-- weeks. Positive lag = search moves first. Finding: correlation peaks at
-- lag 0 wherever it exists — search rank is COINCIDENT, not leading.
WITH prod(concept_id, pid) AS (VALUES
  ('CG-0006',2001933),('CG-0006',1921275),('CG-0006',3545172),('CG-0006',3421343),('CG-0006',3525610),
  ('CG-0008',2002491),('CG-0008',2002484),('CG-0008',3516599),('CG-0008',3544387),('CG-0008',2002521),
  ('CG-0010',3406677),('CG-0010',3609733),('CG-0010',3428601),('CG-0010',2024534),('CG-0010',2759059),
  ('CG-0011',3525607),('CG-0011',2022269),('CG-0011',2022314),('CG-0011',2714281),('CG-0011',3558529),
  ('CG-0012',3353686),('CG-0012',2010977),('CG-0012',3547135),('CG-0012',3381985),('CG-0012',2002104),
  ('CG-0013',2722431),('CG-0013',1513244),('CG-0013',3583960),('CG-0013',3367746),('CG-0013',3644145),
  ('CG-0016',3411590),('CG-0016',3466572),('CG-0016',3448104),
  ('CG-0024',3341614),('CG-0024',3625774),('CG-0024',3630486),('CG-0024',3420774),('CG-0024',2011227)
),
terms(concept_id, term) AS (VALUES
  ('CG-0006','oil sprayer for cooking'),('CG-0006','olive oil sprayer'),('CG-0006','oil sprayer'),('CG-0006','cooking oil sprayer'),
  ('CG-0008','air fryer liners disposable'),('CG-0008','air fryer liners'),('CG-0008','ninja air fryer liners'),('CG-0008','air fryer liner'),('CG-0008','silicone air fryer liners'),
  ('CG-0010','candle warmer lamp'),('CG-0010','candle warmer'),('CG-0010','candle warmer lamp with timer'),('CG-0010','candle warmers'),
  ('CG-0011','meat thermometer'),('CG-0011','meat thermometer digital'),('CG-0011','digital meat thermometer'),('CG-0011','wireless meat thermometer'),('CG-0011','instant read meat thermometer'),
  ('CG-0012','meat chopper'),('CG-0012','ground meat chopper'),('CG-0012','meat chopper for ground beef'),
  ('CG-0013','glass food storage containers with lids'),('CG-0013','glass meal prep containers'),('CG-0013','glass food storage'),('CG-0013','glass food storage containers'),
  ('CG-0016','fridge organizers and storage'),('CG-0016','lazy susan'),('CG-0016','lazy susan organizer for cabinet'),('CG-0016','fridge organizer'),
  ('CG-0024','bento box for kids'),('CG-0024','bento box'),('CG-0024','bento box adult'),('CG-0024','bento lunch box for kids'),('CG-0024','stainless steel bento box')
),
rank_w AS (
  SELECT p.concept_id, date_trunc('week', li.cb_stamp)::date AS wk,
         avg(-ln(li.cb_rank)) AS rank_int
  FROM crystalball.list_item li
  JOIN prod p ON li.cb_product_id = p.pid
  WHERE li.cb_stamp >= date '2024-01-01'   -- PARAM: window start
  GROUP BY 1, 2
),
search_w AS (
  SELECT t.concept_id, date_trunc('week', tp.cb_date_to)::date AS wk,
         avg(-ln(s.cb_rank)) AS search_int
  FROM crystalball.amz_search s
  JOIN crystalball.amz_term_period tp ON tp.cb_period_id = s.cb_period_id
  JOIN terms t ON s.cb_text = t.term
  WHERE tp.cb_date_to >= date '2024-01-01'
  GROUP BY 1, 2
),
series AS (
  SELECT coalesce(r.concept_id, s.concept_id) AS cid,
         coalesce(r.wk, s.wk) AS wk, r.rank_int, s.search_int
  FROM rank_w r
  FULL JOIN search_w s ON r.concept_id = s.concept_id AND r.wk = s.wk
),
d AS (
  SELECT cid, wk,
    search_int - lag(search_int) OVER (PARTITION BY cid ORDER BY wk) AS ds,
    rank_int   - lag(rank_int)   OVER (PARTITION BY cid ORDER BY wk) AS dr
  FROM series
),
lags(k) AS (VALUES (-4),(-2),(0),(2),(4),(6),(8),(12))   -- PARAM: lag set
SELECT a.cid AS concept_id, l.k AS lag_weeks, count(*) AS n_weeks,
       round(corr(a.ds, b.dr)::numeric, 3) AS corr_dsearch_drank
FROM d a
CROSS JOIN lags l
JOIN d b ON b.cid = a.cid AND b.wk = a.wk + l.k * 7
WHERE a.ds IS NOT NULL AND b.dr IS NOT NULL
GROUP BY 1, 2
HAVING count(*) >= 30                                     -- PARAM: min weeks
ORDER BY 1, 2;

-- ---- 2. Outcome-label provenance: exact edges vs regex proxy ---------------
-- CG-0001 (the ledger's flagship concept). Exact = asinxref-verified
-- item_codes from concept_epoca_sku_bridge; regex = the old 06_ledger_refresh
-- style description sweep. Finding: the $24.5M label is 100% regex-attributed;
-- provably-linked items contributed $77 -> curate linked_item_codes for
-- top-IQS call-outs first.
WITH exact_codes(item_code) AS (VALUES
  ('ECACR-3220 DST'),('ECAG-3220 DST'),('ECAGR-3220 DST'),('EOI5-D2816'),
  ('EOI5-D4506'),('EOI5-D5120'),('EOI5-D5124'),('EOI5-D5128'),('EOI6-L5120')
),
exact AS (
  SELECT 'exact_item_code_edges' AS basis, count(DISTINCT h.item_code) AS items,
         sum(h.shipped_qty) AS units, round(sum(h.shipped_dollars)) AS gross
  FROM shaundatabase.v_so_history h
  JOIN exact_codes e ON h.item_code = e.item_code
  WHERE h.yr >= 2025                                       -- PARAM: outcome window
),
regex AS (
  SELECT 'regex_proxy_CA_CER' AS basis, count(DISTINCT h.item_code) AS items,
         sum(h.shipped_qty) AS units, round(sum(h.shipped_dollars)) AS gross
  FROM shaundatabase.v_so_history h
  WHERE h.yr >= 2025
    AND (h.item_code_desc ~* 'cast alum|CA CER' OR h.material_desc ~* 'cast alum')
)
SELECT * FROM exact UNION ALL SELECT * FROM regex;
