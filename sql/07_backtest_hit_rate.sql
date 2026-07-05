-- =====================================================================
-- 07_backtest_hit_rate.sql  —  Crystal Ball Loop 2.0, formula F11
-- The BACKTEST HARNESS: freeze signals at historical dates, pick top-K
-- per strategy, score the picks against what actually ranked 6 and 12
-- months later. Produces the hit-rate table every future model version
-- must beat (see ../docs/BACKTEST_V0.md for the v0 run and findings).
--
-- Universe per (category, t0): "challengers" = products ranked in the
-- category's top-100 lists during the 14 days before t0, with >= min_obs
-- snapshots, and avg recent rank > 10 (top-10 incumbents excluded — the
-- question is who *becomes* a winner, not who already is one).
--
-- Strategies compared (top-K each):
--   A_bestseller        — best current rank (ranks 11, 12, ... — the naive
--                         "closest to the top" pick; the baseline to beat)
--   B_velocity          — pure F1 rank velocity (14d vs 30–44d window)
--   C_vel_plus_reviews  — velocity > 0, ranked by 30d review-count gain
--                         (momentum confirmed by volume; README caveat)
--
-- Outcomes per pick:
--   survival   — >= 5 snapshots in the outcome window (off-list = loss)
--   winner     — avg rank <= 10 (and <= 20) in the outcome window
--   rank gain  — median Δρ = (-ln r_future) - (-ln r_t0), survivors only
--
-- Fairness note: the absolute top-10/20 criterion structurally favors
-- strategy A (its picks start at rank 11–20 and need a one-step move);
-- read precision AND median rank gain together. Validated 2026-07-03.
--
-- PARAMs: t0 freeze dates, category ids, K, min_obs, window offsets.
-- =====================================================================

WITH t0s(t0) AS (
  -- PARAM: freeze dates. Each needs t0 + 390d of outcome data; a t0 within
  -- 13 months of max(cb_stamp) has a truncated 12-month readout (flag it).
  VALUES (date '2024-07-01'), (date '2025-01-01'), (date '2025-07-01')
),
cats(cat_id, cat_name) AS (
  -- PARAM: Amazon categories (region 1), per the map in README.md.
  VALUES (35,'Cookware Sets'), (2,'Bakeware'), (84,'Food Storage'),
         (11,'Gadgets'), (91,'Hydration'), (8,'Drinkware'), (925,'Candles')
),
params AS (
  SELECT 10 AS k, 5 AS min_obs
),
lists AS (
  SELECT c.cat_name, l.cb_list_id FROM cats c
  JOIN crystalball.list l
    ON l.cb_category_id = c.cat_id AND l.cb_region_id = 1
),
obs AS (
  SELECT ls.cat_name, t.t0, li.cb_product_id,
    -- signal windows (as of t0 — no look-ahead)
    count(*)        FILTER (WHERE li.cb_stamp > t.t0 - 14 AND li.cb_stamp <= t.t0) AS n_recent,
    avg(li.cb_rank) FILTER (WHERE li.cb_stamp > t.t0 - 14 AND li.cb_stamp <= t.t0) AS r_now,
    avg(li.cb_rank) FILTER (WHERE li.cb_stamp BETWEEN t.t0 - 44 AND t.t0 - 30)     AS r_mid,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp > t.t0 - 7 AND li.cb_stamp <= t.t0) AS rev_now,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp BETWEEN t.t0 - 37 AND t.t0 - 23)    AS rev_prev,
    -- outcome windows
    count(*)        FILTER (WHERE li.cb_stamp BETWEEN t.t0 + 150 AND t.t0 + 210)   AS n_fut6,
    avg(li.cb_rank) FILTER (WHERE li.cb_stamp BETWEEN t.t0 + 150 AND t.t0 + 210)   AS r_fut6,
    count(*)        FILTER (WHERE li.cb_stamp BETWEEN t.t0 + 330 AND t.t0 + 390)   AS n_fut12,
    avg(li.cb_rank) FILTER (WHERE li.cb_stamp BETWEEN t.t0 + 330 AND t.t0 + 390)   AS r_fut12
  FROM crystalball.list_item li
  JOIN lists ls ON li.cb_list_id = ls.cb_list_id
  CROSS JOIN t0s t
  WHERE li.cb_stamp BETWEEN t.t0 - 44 AND t.t0 + 390
  GROUP BY 1, 2, 3
),
challengers AS (
  SELECT o.*,
    (-ln(r_now)) - (-ln(r_mid))                  AS velocity,   -- F1
    coalesce(rev_now, 0) - coalesce(rev_prev, 0) AS rev_gain    -- F3 (30d)
  FROM obs o, params p
  WHERE r_now IS NOT NULL AND r_mid IS NOT NULL
    AND n_recent >= p.min_obs
    AND r_now > 10                                -- exclude top-10 incumbents
),
picks AS (
  -- cb_product_id tie-breakers keep pick sets deterministic across runs
  SELECT *,
    row_number() OVER (PARTITION BY cat_name, t0
      ORDER BY r_now ASC, cb_product_id)                                 AS rn_base,
    row_number() OVER (PARTITION BY cat_name, t0
      ORDER BY velocity DESC, cb_product_id)                             AS rn_vel,
    row_number() OVER (PARTITION BY cat_name, t0
      ORDER BY CASE WHEN velocity > 0 THEN rev_gain END DESC NULLS LAST,
               cb_product_id)                                            AS rn_comp
  FROM challengers
),
strat AS (
  SELECT 'A_bestseller' AS strategy, p.* FROM picks p, params pr WHERE p.rn_base <= pr.k
  UNION ALL
  SELECT 'B_velocity',              p.* FROM picks p, params pr WHERE p.rn_vel  <= pr.k
  UNION ALL
  SELECT 'C_vel_plus_reviews',      p.* FROM picks p, params pr
    WHERE p.rn_comp <= pr.k AND p.velocity > 0
)
SELECT strategy, coalesce(cat_name, 'ALL') AS category,
  count(*)                                             AS picks,
  count(*) FILTER (WHERE n_fut6  >= 5)                 AS surv6,
  count(*) FILTER (WHERE n_fut6  >= 5 AND r_fut6  <= 10) AS win6_top10,
  count(*) FILTER (WHERE n_fut6  >= 5 AND r_fut6  <= 20) AS win6_top20,
  count(*) FILTER (WHERE n_fut12 >= 5)                 AS surv12,
  count(*) FILTER (WHERE n_fut12 >= 5 AND r_fut12 <= 10) AS win12_top10,
  count(*) FILTER (WHERE n_fut12 >= 5 AND r_fut12 <= 20) AS win12_top20,
  round((percentile_cont(0.5) WITHIN GROUP
         (ORDER BY ((-ln(r_fut6))  - (-ln(r_now)))))::numeric, 3) AS med_gain6,
  round((percentile_cont(0.5) WITHIN GROUP
         (ORDER BY ((-ln(r_fut12)) - (-ln(r_now)))))::numeric, 3) AS med_gain12
FROM strat
GROUP BY GROUPING SETS ((strategy), (strategy, cat_name))
ORDER BY category, strategy;

-- Winner detail: to list the individual picks that reached top-20 at 6mo
-- (titles, rank_at_t0 -> rank_6mo_later), replace the final SELECT with a
-- join from `picks` (filtered to one strategy's rn_* <= k) through
-- crystalball.amz_product -> crystalball.list_item_title, keeping rows
-- WHERE n_fut6 >= 5 AND r_fut6 <= 20 ORDER BY r_fut6.
