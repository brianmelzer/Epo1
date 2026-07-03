-- =====================================================================
-- 03_cross_retailer_gap.sql  —  Crystal Ball Loop 2.0, formula F12
-- Concepts strong on one marketplace but THIN on another = early, low-risk
-- private-label picks (the whitespace a buyer cares most about).
--
-- Product keys do NOT match across retailers, so we compare by CONCEPT KEYWORD:
-- best recent rank + how many distinct products carry the concept on each side.
-- The product-count disparity is often a sharper gap signal than rank alone.
-- Validated 2026-07-02: "titanium" cookware = 57 Amazon products (best #1) vs
-- only 5 on Walmart (best #19) -> genuine Walmart whitespace.
--
-- PARAMs: concept list, Amazon category ids, Walmart list ids, anchor, window.
-- =====================================================================

WITH params AS (SELECT date '2026-07-02' AS anchor, 14 AS w_recent),   -- PARAM
kw(concept) AS (VALUES        -- PARAM: concepts to test (features, materials, forms)
  ('cast aluminum'),('detachable handle'),('titanium'),('nonstick'),
  ('ceramic'),('induction'),('bamboo'),('glass'),('stackable'),('enamel')),
amz AS (
  SELECT k.concept,
         min(li.cb_rank)                    AS amz_best_rank,
         count(DISTINCT li.cb_product_id)   AS amz_products
  FROM kw k, params p
  JOIN crystalball.list_item_title t ON lower(t.cb_title) LIKE '%'||k.concept||'%'
  JOIN crystalball.amz_product     pr ON pr.cb_title_id = t.cb_title_id
  JOIN crystalball.list_item       li ON li.cb_product_id = pr.cb_product_id
  JOIN crystalball.list            l  ON l.cb_list_id = li.cb_list_id
     AND l.cb_region_id = 1 AND l.cb_category_id IN (5,35,45)   -- PARAM: Amazon cookware
  WHERE li.cb_stamp >= p.anchor - p.w_recent
  GROUP BY k.concept
),
wm AS (
  SELECT k.concept,
         min(wi.cb_rank)                    AS wm_best_rank,
         count(DISTINCT wi.cb_product_id)   AS wm_products
  FROM kw k, params p
  JOIN crystalball.wm_title    t  ON lower(t.cb_title) LIKE '%'||k.concept||'%'
  JOIN crystalball.wm_product  pr ON pr.cb_title_id = t.cb_title_id
  JOIN crystalball.wm_list_item wi ON wi.cb_product_id = pr.cb_product_id
     AND wi.cb_list_id IN (143,149,150,140)                     -- PARAM: Walmart cookware
  WHERE wi.cb_stamp >= p.anchor - p.w_recent
  GROUP BY k.concept
)
SELECT kw.concept,
  a.amz_best_rank, a.amz_products,
  w.wm_best_rank,  coalesce(w.wm_products, 0) AS wm_products,
  CASE
    WHEN a.amz_best_rank <= 15
     AND (w.wm_products IS NULL OR a.amz_products >= 3 * coalesce(w.wm_products,0) + 3)
    THEN 'GAP: proven on Amazon, under-served on Walmart'
    ELSE ''
  END AS signal
FROM kw
LEFT JOIN amz a ON a.concept = kw.concept
LEFT JOIN wm  w ON w.concept = kw.concept
ORDER BY (a.amz_products::numeric / NULLIF(coalesce(w.wm_products,0),0)) DESC NULLS LAST;
