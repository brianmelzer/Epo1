-- =====================================================================
-- 09_concept_graph_extracts.sql — Concept Graph v0 source extracts
-- Refreshes data/concept_graph/extracts/*.csv, the inputs to
-- scripts/concept_graph_build.py. The DB role is READ-ONLY, so the graph
-- itself lives in-repo as versioned CSVs; these queries only *propose*
-- match candidates — the builder assigns match_type/confidence and the
-- review queue (or PR review) decides.
--
-- Patterns come from data/concept_graph/matching_rules.csv (the rules
-- file is the source of truth; the VALUES lists below mirror it).
-- Validated 2026-07-05. Save each result as the named extract CSV.
-- =====================================================================

-- ---- 1. product_matches.csv --------------------------------------------
-- Per-concept L2 title rules against products ranked in the last 90 days
-- in the concept's mapped Amazon categories. Top 5 per concept by best rank.
WITH rules(concept_id, cats, pattern) AS (
  VALUES ('CG-0001', ARRAY[35,45], 'cast alumin')  -- ... all product rules from matching_rules.csv
),
anchor AS (SELECT max(cb_stamp) AS d FROM crystalball.list_item),
lists AS (
  SELECT r.concept_id, r.pattern, l.cb_list_id
  FROM rules r JOIN crystalball.list l
    ON l.cb_region_id = 1 AND l.cb_category_id = ANY(r.cats)
),
recent AS (
  SELECT ls.concept_id, ls.pattern, li.cb_product_id,
         min(li.cb_rank) AS best_rank
  FROM crystalball.list_item li
  JOIN lists ls ON li.cb_list_id = ls.cb_list_id
  CROSS JOIN anchor a
  WHERE li.cb_stamp >= a.d - 90
  GROUP BY 1, 2, 3
),
matched AS (
  SELECT r.concept_id, r.cb_product_id, p.cb_asin, t.cb_title, r.best_rank,
         row_number() OVER (PARTITION BY r.concept_id
                            ORDER BY r.best_rank, r.cb_product_id) AS rn
  FROM recent r
  JOIN crystalball.amz_product p ON p.cb_product_id = r.cb_product_id
  JOIN crystalball.list_item_title t ON t.cb_title_id = p.cb_title_id
  WHERE t.cb_title ~* r.pattern
)
SELECT concept_id, cb_product_id, cb_asin,
       left(regexp_replace(cb_title, '[,\n\r"]', ' ', 'g'), 60) AS title, best_rank
FROM matched WHERE rn <= 5 ORDER BY concept_id, best_rank;

-- ---- 2. search_matches.csv ----------------------------------------------
-- Search-term rules over the most recent 8 weekly periods. level_of_truth
-- for these edges is CONCEPT (terms describe concepts, not single products).
WITH rules(concept_id, pattern) AS (
  VALUES ('CG-0006', 'oil sprayer|oil mister')  -- ... all search rules
),
periods AS (
  SELECT cb_period_id FROM crystalball.amz_term_period
  ORDER BY cb_date_to DESC LIMIT 8
),
hits AS (
  SELECT r.concept_id, s.cb_text, min(s.cb_rank) AS best_rank,
         count(DISTINCT s.cb_period_id) AS n_periods,
         row_number() OVER (PARTITION BY r.concept_id ORDER BY min(s.cb_rank)) AS rn
  FROM crystalball.amz_search s
  JOIN periods p ON s.cb_period_id = p.cb_period_id
  JOIN rules r ON s.cb_text ~* r.pattern
  GROUP BY 1, 2
)
SELECT concept_id, cb_text AS search_text, best_rank, n_periods
FROM hits WHERE rn <= 5 ORDER BY concept_id, best_rank;

-- ---- 3. social_matches.csv ----------------------------------------------
-- Hashtag rules; most tags resolve at CATEGORY level — label honestly via
-- level_hint. followed_since matters for backtests (coverage begins there).
WITH pats(concept_id, level_hint, pattern) AS (
  VALUES ('CG-0010', 'concept', 'candlewarmer'),
         ('CAT-KITCHEN', 'category', 'kitchengadget|cookware|kitchenware')  -- ... all social rules
)
SELECT DISTINCT p.concept_id, p.level_hint, h.cb_hashtag_id, h.cb_hashtag AS hashtag,
       (c.cb_collection_id IS NOT NULL) AS followed,
       c.cb_start_to_follow::date AS followed_since
FROM crystalball.sm_hashtag h
JOIN pats p ON h.cb_hashtag ~* p.pattern
LEFT JOIN crystalball.sm_collection c
       ON c.cb_hashtag_id = h.cb_hashtag_id AND c.cb_active
WHERE length(h.cb_hashtag) <= 30 AND NOT h.cb_ignore_flag
ORDER BY p.concept_id, h.cb_hashtag;

-- ---- 4. epoca_asinxref_matches.csv ---------------------------------------
-- The exact-key chain: asinxref (ASIN <-> item_code, exact) joined to Amazon
-- titles, concept assigned by the product rule. The ASIN<->item_code link is
-- EXACT; the concept assignment is rule-based and reviewable.
WITH rules(concept_id, pattern) AS (
  VALUES ('CG-0001', 'cast alumin')  -- ... product rules
)
SELECT DISTINCT r.concept_id, x.asin, x.item_code,
       left(regexp_replace(t.cb_title, '[,\n\r"]', ' ', 'g'), 60) AS amz_title
FROM shaundatabase.asinxref x
JOIN crystalball.amz_product p ON p.cb_asin = x.asin
JOIN crystalball.list_item_title t ON t.cb_title_id = p.cb_title_id
JOIN rules r ON t.cb_title ~* r.pattern
ORDER BY r.concept_id, x.item_code;

-- ---- 5. walmart_matches.csv ----------------------------------------------
-- Cross-retailer sample bridge (title-only; confidence penalized 0.9x).
WITH rules(concept_id, pattern) AS (
  VALUES ('CG-0010', 'candle warmer')  -- ... subset of product rules
),
m AS (
  SELECT r.concept_id, p.cb_product_id, p.cb_walmart_id,
         left(regexp_replace(t.cb_title, '[,\n\r"]', ' ', 'g'), 55) AS title,
         row_number() OVER (PARTITION BY r.concept_id ORDER BY p.cb_product_id) AS rn
  FROM crystalball.wm_product p
  JOIN crystalball.wm_title t ON t.cb_title_id = p.cb_title_id
  JOIN rules r ON t.cb_title ~* r.pattern
)
SELECT concept_id, cb_product_id, trim(cb_walmart_id) AS walmart_id, title
FROM m WHERE rn <= 4 ORDER BY concept_id;
