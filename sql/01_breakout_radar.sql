-- =====================================================================
-- 01_breakout_radar.sql  —  Crystal Ball Loop 2.0, formulas F1 + F2 + F3
-- Per-product rank VELOCITY, ACCELERATION, and REVIEW VELOCITY in a category.
-- This is the engine behind the "climbers" slide that ships with live numbers.
--
-- Rank note: lower rank = more popular. We work in rho = -ln(rank) so equal
-- proportional moves count equally. Validated against Amazon Cookware Sets
-- (cat 35, region 1) on 2026-07-02.
--
-- PARAMs to set: anchor date, category id(s), region, windows, min-obs.
-- =====================================================================

WITH params AS (
  SELECT
    date '2026-07-02'      AS anchor,   -- PARAM: latest cb_stamp
    14                     AS w_recent,  -- PARAM: recent window (days)
    30                     AS w_prev_a,  -- PARAM: prior window start offset
    44                     AS w_prev_b,  -- PARAM: prior window end offset
    60                     AS w_base_a,  -- PARAM: baseline window start offset
    74                     AS w_base_b,  -- PARAM: baseline window end offset
    5                      AS min_obs     -- PARAM: min snapshots per product
),
lists AS (
  -- PARAM: category selection. Here: Amazon Cookware Sets (35), US region 1.
  SELECT cb_list_id FROM crystalball.list
  WHERE cb_region_id = 1 AND cb_category_id IN (35)
),
w AS (
  SELECT li.cb_product_id,
    count(*) FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                                     AS n_recent,
    avg(li.cb_rank)  FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                             AS r_now,
    avg(li.cb_rank)  FILTER (WHERE li.cb_stamp BETWEEN p.anchor - p.w_prev_b AND p.anchor - p.w_prev_a) AS r_mid,
    avg(li.cb_rank)  FILTER (WHERE li.cb_stamp BETWEEN p.anchor - p.w_base_b AND p.anchor - p.w_base_a) AS r_old,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp >= p.anchor - 7)                               AS rev_now,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp BETWEEN p.anchor - 37 AND p.anchor - 23)       AS rev_prev,
    avg(li.cb_rating) FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                            AS rating,
    avg(li.cb_price)  FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                            AS price
  FROM crystalball.list_item li, params p
  WHERE li.cb_list_id IN (SELECT cb_list_id FROM lists)
    AND li.cb_stamp >= p.anchor - p.w_base_b
  GROUP BY li.cb_product_id
)
SELECT
  left(t.cb_title, 70)                                            AS product,
  round(w.r_old)  AS rank_base,
  round(w.r_mid)  AS rank_prior,
  round(w.r_now)  AS rank_now,
  round(((-ln(w.r_now)) - (-ln(w.r_mid)))::numeric, 3)           AS velocity,      -- F1
  round((((-ln(w.r_now)) - (-ln(w.r_mid)))
        - ((-ln(w.r_mid)) - (-ln(w.r_old))))::numeric, 3)        AS acceleration, -- F2
  (w.rev_now - w.rev_prev)                                        AS review_gain_30d, -- F3 (sales proxy)
  round(w.rating, 2)                                             AS rating,
  round(w.price)                                                AS price
FROM w
JOIN crystalball.amz_product     p ON p.cb_product_id = w.cb_product_id
JOIN crystalball.list_item_title t ON t.cb_title_id  = p.cb_title_id,
     params pr
WHERE w.r_now IS NOT NULL AND w.r_mid IS NOT NULL AND w.r_old IS NOT NULL
  AND w.n_recent >= pr.min_obs
ORDER BY velocity DESC          -- swap to review_gain_30d DESC for a "volume winners" cut
LIMIT 15;
