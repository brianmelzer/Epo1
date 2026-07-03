-- =====================================================================
-- 02_feature_lift.sql  —  Crystal Ball Loop 2.0, formula F9
-- Which title FEATURES / BENEFITS are associated with faster movement?
-- Turns the "features & benefits trending" ask into a measured leaderboard.
--
-- IMPORTANT CAVEAT (validated 2026-07-02): over a broad, long-tail category the
-- AVERAGE product mean-reverts, so raw rank-velocity lift reads negative for
-- almost every feature and MISLEADS. Two honest fixes, both applied below:
--   (a) restrict to higher-traffic products (recent rank <= TOP_N), and
--   (b) also report lift on REVIEW VELOCITY (real volume), not just rank.
-- A few titanium / detachable-handle SKUs rocket while the average one declines,
-- so always read n_with alongside the lift.
--
-- PARAMs: anchor, category, windows, TOP_N, and the feature token list.
-- =====================================================================

WITH params AS (
  SELECT date '2026-07-02' AS anchor,   -- PARAM
         14 AS w_recent, 30 AS w_prev_a, 44 AS w_prev_b,
         50 AS top_n                     -- PARAM: only products ranking <= top_n recently
),
lists AS (
  -- PARAM: Amazon Cookware subtree (cat 5 + children + Sets 35), US region 1.
  SELECT l.cb_list_id FROM crystalball.list l
  JOIN crystalball.list_category c ON c.cb_category_id = l.cb_category_id
  WHERE l.cb_region_id = 1
    AND (c.cb_category_id = 5 OR c.cb_parent_id = 5 OR c.cb_category_id = 35)
),
v AS (
  SELECT li.cb_product_id,
    avg(li.cb_rank) FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent) AS r_now,
    (-ln(avg(li.cb_rank) FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)))
      - (-ln(avg(li.cb_rank) FILTER (WHERE li.cb_stamp BETWEEN p.anchor - p.w_prev_b AND p.anchor - p.w_prev_a))) AS velocity,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp >= p.anchor - 7)
      - max(li.cb_review_count) FILTER (WHERE li.cb_stamp BETWEEN p.anchor - 37 AND p.anchor - 23) AS review_gain
  FROM crystalball.list_item li, params p
  WHERE li.cb_list_id IN (SELECT cb_list_id FROM lists)
    AND li.cb_stamp >= p.anchor - p.w_prev_b
  GROUP BY li.cb_product_id
),
pv AS (
  SELECT lower(t.cb_title) AS title, v.velocity, v.review_gain
  FROM v
  JOIN crystalball.amz_product p ON p.cb_product_id = v.cb_product_id
  JOIN crystalball.list_item_title t ON t.cb_title_id = p.cb_title_id, params pr
  WHERE v.velocity IS NOT NULL AND v.r_now <= pr.top_n     -- (a) higher-traffic only
),
feat(f) AS (VALUES              -- PARAM: feature/benefit tokens to test
  ('pfas'),('nonstick'),('ceramic'),('titanium'),('cast iron'),
  ('cast aluminum'),('stainless'),('non-toxic'),('induction'),
  ('detachable handle'),('stackable'),('granite'),('enamel'))
SELECT f AS feature,
  count(*) FILTER (WHERE title LIKE '%'||f||'%')                                             AS n_with,
  round(avg(velocity)    FILTER (WHERE title LIKE '%'||f||'%')::numeric, 3)                  AS vel_with,
  round((avg(velocity) FILTER (WHERE title LIKE '%'||f||'%')
       - avg(velocity) FILTER (WHERE title NOT LIKE '%'||f||'%'))::numeric, 3)              AS vel_lift,
  round(avg(review_gain) FILTER (WHERE title LIKE '%'||f||'%')::numeric, 0)                  AS rev_gain_with,
  round((avg(review_gain) FILTER (WHERE title LIKE '%'||f||'%')
       - avg(review_gain) FILTER (WHERE title NOT LIKE '%'||f||'%'))::numeric, 0)           AS rev_gain_lift
FROM pv, feat
GROUP BY f
HAVING count(*) FILTER (WHERE title LIKE '%'||f||'%') >= 5     -- PARAM: min support
ORDER BY rev_gain_lift DESC NULLS LAST;
