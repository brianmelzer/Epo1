-- =====================================================================
-- 01_breakout_radar.sql  —  Crystal Ball Loop 2.0, PWS_v1 breakout radar
-- Per-product composite score (PWS_v1) in a category: proximity-dominant
-- blend of rank proximity, rank velocity, review-volume growth, and a
-- price-band commercial filter. This is the engine behind the "climbers"
-- slide that ships with live numbers.
--
-- CHANGE (2026-07-06): ranking upgraded from raw velocity (F1) to the
-- Backtest v1 composite PWS_v1 (docs/BACKTEST_V1_RESULTS.md, strategy G2).
-- Backtest v1 (validated live 2026-07-05, 200 picks x 2 horizons) falsified
-- pure velocity as a standalone ranker (1/200 top-10 winners at 6mo, 28%
-- survival — the single most destructive addition in the ablation ladder)
-- and validated a proximity-dominant blend:
--
--   PWS_v1 = 1.5*z(-ln r_now) + 0.25*z(V) + 0.75*z(ln(1+rev_gain))
--          + 0.5*z(SDV) + 0.25*PB
--
-- This radar implements PWS_v1 WITHOUT the search term (z(SDV), weight 0.5):
-- Backtest v1 §2.4 / finding 4 showed weekly top-25k search terms matched
-- by title substring are CONCEPT-level only — many products tie on one
-- generic term's score — so SDV subtracts precision when used to rank
-- individual ASINs within a category. It is deliberately dropped here;
-- use it (if at all) at the concept/keyword rollup level (09_*).
--
--   PWS_radar = 1.5*z(prox) + 0.25*z(vel) + 0.75*z(lnRevGain) + 0.25*PB
--
-- z() = z-score within the category's qualifying universe at the anchor
-- date; missing z-inputs are imputed to 0 (per the backtest protocol).
-- PB = 1 if the 14d avg price sits within [p25, p75] of the category's
-- price distribution at the anchor.
--
-- VELOCITY (F1) is kept as a visible column — see the WATCH note at the
-- SELECT below — but it no longer drives the ordering.
--
-- Rank note: lower rank = more popular. We work in rho = -ln(rank) so equal
-- proportional moves count equally. Validated against Amazon Cookware Sets
-- (cat 35, region 1) on 2026-07-06.
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
),
-- Price band over the FULL category universe (not just qualifying rows),
-- matching Backtest v1's PB definition (p25..p75 of the category top-100
-- price distribution at the anchor).
band AS (
  SELECT
    percentile_cont(0.25) WITHIN GROUP (ORDER BY price) AS p25,
    percentile_cont(0.75) WITHIN GROUP (ORDER BY price) AS p75
  FROM w
  WHERE price IS NOT NULL
),
-- Raw signal inputs, restricted to the qualifying universe (same filters
-- as before: full window coverage + min recent snapshots).
sig AS (
  SELECT w.*,
    -ln(w.r_now)                                                  AS prox,       -- proximity: rho now
    (-ln(w.r_now)) - (-ln(w.r_mid))                               AS vel,        -- F1 velocity
    ((-ln(w.r_now)) - (-ln(w.r_mid)))
      - ((-ln(w.r_mid)) - (-ln(w.r_old)))                         AS accel,      -- F2 acceleration
    (w.rev_now - w.rev_prev)                                      AS rev_gain,   -- F3 (sales proxy)
    CASE WHEN w.rev_now IS NOT NULL AND w.rev_prev IS NOT NULL
         THEN ln(1 + greatest(w.rev_now - w.rev_prev, 0))
    END                                                           AS lrg,        -- ln review gain (NULL -> z imputed 0)
    CASE WHEN w.price BETWEEN b.p25 AND b.p75 THEN 1 ELSE 0 END   AS pb          -- price-band commercial filter
  FROM w CROSS JOIN band b, params pr
  WHERE w.r_now IS NOT NULL AND w.r_mid IS NOT NULL AND w.r_old IS NOT NULL
    AND w.n_recent >= pr.min_obs
),
-- Z-scores within the category's qualifying universe; NULL inputs (e.g. no
-- review history) and zero-variance signals impute to z = 0.
z AS (
  SELECT sig.*,
    coalesce((prox - avg(prox) OVER ()) / nullif(stddev_samp(prox) OVER (), 0), 0) AS z_prox,
    coalesce((vel  - avg(vel)  OVER ()) / nullif(stddev_samp(vel)  OVER (), 0), 0) AS z_vel,
    coalesce((lrg  - avg(lrg)  OVER ()) / nullif(stddev_samp(lrg)  OVER (), 0), 0) AS z_lrg
  FROM sig
)
SELECT
  left(t.cb_title, 70)                                            AS product,
  round(z.r_old)  AS rank_base,
  round(z.r_mid)  AS rank_prior,
  round(z.r_now)  AS rank_now,
  round((1.5 * z.z_prox + 0.25 * z.z_vel
       + 0.75 * z.z_lrg + 0.25 * z.pb)::numeric, 3)               AS pws_v1,        -- THE ranking score (search term dropped, see header)
  round(z.z_prox::numeric, 2)                                     AS z_prox,
  round(z.vel::numeric, 3)                                        AS velocity,      -- F1 — WATCH column only: falsified as a
                                                                                    -- standalone ranker by Backtest v1 (1/200
                                                                                    -- top-10 winners; do NOT sort by this)
  round(z.accel::numeric, 3)                                      AS acceleration,  -- F2 (context)
  z.rev_gain                                                      AS review_gain_30d, -- F3 (sales proxy)
  z.pb                                                            AS price_band,    -- 1 = inside category p25..p75
  round(z.rating, 2)                                              AS rating,
  round(z.price)                                                  AS price
FROM z
JOIN crystalball.amz_product     p ON p.cb_product_id = z.cb_product_id
JOIN crystalball.list_item_title t ON t.cb_title_id  = p.cb_title_id
ORDER BY pws_v1 DESC            -- PWS_v1 blend (Backtest v1, docs/BACKTEST_V1_RESULTS.md)
LIMIT 15;
