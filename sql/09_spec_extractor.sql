-- =====================================================================
-- 09_spec_extractor.sql  —  SPEC-LEVEL EXTRACTOR (item-spec whitespace)
-- Moves Crystal Ball from category-level calls ("glass food storage is
-- trending") to ITEM-SPEC calls ("30-pc glass set, snap lids, $39").
--
-- Stage A parses each product TITLE into a spec vector (piece_count,
-- material, lid_type, form) + a price band from cb_price, then aggregates
-- SPEC CELLS = material x piece-band x price-band with:
--   competitors   = products in the cell ranked in the recent window
--   avg_rank      = avg recent rank (lower = hotter shelf position)
--   velocity      = F1 rank velocity in rho = -ln(rank), 14d vs 30-44d
--   rev_gain_30d  = 30d review gain summed over the cell (sales proxy, F3)
--   whitespace    = momentum-per-competitor (hot + underoccupied)
--
-- Pilot: Amazon Food Storage (cb_category_id 84, region 1), anchored
-- 2026-07-04. Validated: the Razab 30-pc glass climber lands in
-- glass x 30+ x $30-50 and the BRIVARA ceramic-coated climbers land in
-- ceramic-coated x 10-19 x $50+ — both hot cells (see
-- ../docs/SPEC_LEVEL_BREAKOUT_FOODSTORAGE.md).
--
-- The parser is generic: to run another category only the `lists` CTE
-- changes (or swap in wm_list/wm_list_item for Walmart).
--
-- CAVEATS (honest ones):
--  * Cells are computed WITHIN top-100 lists only — "competitors = 4"
--    means 4 products currently ranked, not 4 on all of Amazon.
--  * piece_count takes the FIRST "N pc/pcs/piece/pack" match; titles like
--    "50 Pack (100-Piece)" parse as 50, "10 Sets (20-Piece)" as 20.
--  * Broad categories carry contamination (juice bottles, sushi trays
--    ride the Food Storage lists) — sanity-check cell members (Stage B).
--  * MATERIALIZED hints matter: without them the planner inlines `w` and
--    the query blows past the ~60s gateway limit.
-- =====================================================================

WITH params AS (
  SELECT
    date '2026-07-04' AS anchor,      -- PARAM: SELECT max(cb_stamp) FROM crystalball.list_item
    14                AS w_recent,    -- PARAM: recent window (days)
    30                AS w_prev_a,    -- PARAM: prior window start offset
    44                AS w_prev_b,    -- PARAM: prior window end offset
    2                 AS min_comp,    -- PARAM: min competitors for a cell to print
    2                 AS min_vel_obs  -- PARAM: min products with both windows before trusting cell velocity
),
lists AS MATERIALIZED (
  -- PARAM: category selection. Pilot: Amazon Food Storage (84), US region 1.
  SELECT cb_list_id FROM crystalball.list
  WHERE cb_region_id = 1 AND cb_category_id IN (84)
),

-- ---------------------------------------------------------------------
-- Windowed per-product metrics (same windows as 01_breakout_radar.sql)
-- ---------------------------------------------------------------------
w AS MATERIALIZED (
  SELECT li.cb_product_id,
    avg(li.cb_rank)  FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                                  AS r_now,
    avg(li.cb_rank)  FILTER (WHERE li.cb_stamp BETWEEN p.anchor - p.w_prev_b AND p.anchor - p.w_prev_a)   AS r_mid,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp >= p.anchor - 7)                                    AS rev_now,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp BETWEEN p.anchor - 37 AND p.anchor - 23)            AS rev_prev,
    avg(li.cb_rating) FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                                 AS rating,
    avg(li.cb_price)  FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                                 AS price
  FROM crystalball.list_item li, params p
  WHERE li.cb_list_id IN (SELECT cb_list_id FROM lists)
    AND li.cb_stamp >= p.anchor - p.w_prev_b
  GROUP BY li.cb_product_id
),

-- ---------------------------------------------------------------------
-- Stage A: TITLE -> spec vector. Regexes are lowercase (titles lower()ed);
-- CASE order encodes priority (e.g. 'ceramic-coated' outranks 'glass',
-- 'glass lid'/'bamboo lid' are stripped so lids don't set the material).
-- ---------------------------------------------------------------------
parsed AS MATERIALIZED (
  SELECT w.*, p.cb_asin, t.cb_title,
    -- piece_count: first "N pc/pcs/piece(s)/pack/pk/ct/count" match,
    -- fallback "set/pack of N". First-match rule: "10 Sets (20-Piece)"
    -- -> 20 (correct), "50 Pack (100-Piece)" -> 50 (units, not pieces).
    COALESCE(
      substring(lower(t.cb_title) FROM '(\d{1,3})[ -]?(?:pcs?|pieces?|packs?|pk|ct|count)\y')::int,
      substring(lower(t.cb_title) FROM '(?:set|pack) of (\d{1,3})')::int)          AS piece_count,
    CASE
      WHEN lower(t.cb_title) ~ 'ceramic[ -]?coat'                                  THEN 'ceramic-coated'
      WHEN lower(t.cb_title) ~ 'borosilicate'                                      THEN 'glass'
      WHEN regexp_replace(lower(t.cb_title), 'glass lids?',  '', 'g') ~ 'glass'    THEN 'glass'
      WHEN lower(t.cb_title) ~ 'stainless'                                         THEN 'stainless'
      WHEN lower(t.cb_title) ~ 'ceramic'                                           THEN 'ceramic'
      WHEN lower(t.cb_title) ~ 'silicone'                                          THEN 'silicone'
      WHEN lower(t.cb_title) ~ 'plastic'                                           THEN 'plastic'
      WHEN regexp_replace(lower(t.cb_title), 'bamboo lids?', '', 'g') ~ 'bamboo'   THEN 'bamboo'
    END                                                                            AS material,
    CASE
      WHEN lower(t.cb_title) ~ 'bamboo lid'      THEN 'bamboo lid'
      WHEN lower(t.cb_title) ~ 'vacuum'          THEN 'vacuum'
      WHEN lower(t.cb_title) ~ '(snap|locking)'  THEN 'snap/locking'
      WHEN lower(t.cb_title) ~ 'airtight'        THEN 'airtight'
      WHEN lower(t.cb_title) ~ 'leak[ -]?proof'  THEN 'leakproof'
      WHEN lower(t.cb_title) ~ 'glass lid'       THEN 'glass lid'
      WHEN lower(t.cb_title) ~ 'plastic lid'     THEN 'plastic lid'
    END                                                                            AS lid_type,
    CASE
      WHEN lower(t.cb_title) ~ '(divided|compartment)' THEN 'divided'
      WHEN lower(t.cb_title) ~ 'bento'                 THEN 'bento'
      WHEN lower(t.cb_title) ~ 'meal prep'             THEN 'meal prep'
      WHEN lower(t.cb_title) ~ '(nesting|stackable)'   THEN 'nesting/stackable'
      WHEN lower(t.cb_title) ~ 'rectangular'           THEN 'rectangular'
      WHEN lower(t.cb_title) ~ 'round'                 THEN 'round'
      WHEN lower(t.cb_title) ~ '(jar|canister)'        THEN 'jar/canister'
    END                                                                            AS form
  FROM w
  JOIN crystalball.amz_product     p ON p.cb_product_id = w.cb_product_id
  JOIN crystalball.list_item_title t ON t.cb_title_id   = p.cb_title_id
),

-- ---------------------------------------------------------------------
-- Spec cells: material x piece band x price band
-- ---------------------------------------------------------------------
cells AS (
  SELECT
    material,
    CASE WHEN piece_count >= 30 THEN '30+'  WHEN piece_count >= 20 THEN '20-29'
         WHEN piece_count >= 10 THEN '10-19' ELSE '1-9' END              AS pc_band,
    CASE WHEN price >= 50 THEN '$50+'  WHEN price >= 30 THEN '$30-50'
         WHEN price >= 15 THEN '$15-30' ELSE '<$15' END                  AS price_band,
    count(*) FILTER (WHERE r_now IS NOT NULL)                            AS competitors,
    round(avg(r_now))                                                    AS avg_rank,
    round(avg((-ln(r_now)) - (-ln(r_mid)))::numeric, 3)                  AS velocity,       -- F1, cell mean
    count(*) FILTER (WHERE r_now IS NOT NULL AND r_mid IS NOT NULL)      AS n_vel,          -- products behind velocity
    sum(rev_now - rev_prev)                                              AS rev_gain_30d,   -- F3, cell sum
    max(rev_now - rev_prev)                                              AS top_rev_gain,   -- best seller's 30d gain
    round(avg(rating)::numeric, 2)                                       AS rating
  FROM parsed
  WHERE material IS NOT NULL AND piece_count IS NOT NULL AND price IS NOT NULL
  GROUP BY 1, 2, 3
)

-- ---------------------------------------------------------------------
-- Rank cells by momentum-per-competitor (whitespace score):
--   (100 * velocity_clipped_at_0  +  sqrt(review_gain))  / competitors
-- Velocity below min_vel_obs products -> score NULL (don't trust a
-- one-product cell mean; it still prints for inspection).
-- ---------------------------------------------------------------------
SELECT c.material, c.pc_band, c.price_band,
  c.competitors, c.avg_rank, c.velocity, c.n_vel,
  c.rev_gain_30d, c.top_rev_gain, c.rating,
  CASE WHEN c.n_vel >= p.min_vel_obs THEN
    round(((100 * greatest(c.velocity, 0)
            + sqrt(greatest(coalesce(c.rev_gain_30d, 0), 0)))
           / c.competitors)::numeric, 1)
  END AS whitespace_score
FROM cells c, params p
WHERE c.competitors >= p.min_comp
ORDER BY whitespace_score DESC NULLS LAST, velocity DESC NULLS LAST;

-- =====================================================================
-- Stage B (drill-down): who is actually in a hot cell? Swap the final
-- SELECT above for this one to name the ASINs behind a cell before
-- writing a buy call (keeps the whole file one gateway-sized query).
--
-- SELECT cb_asin, left(cb_title, 90) AS title, piece_count, material,
--        lid_type, form, round(price) AS price, round(r_mid) AS rank_prior,
--        round(r_now) AS rank_now, (rev_now - rev_prev) AS rev_gain_30d,
--        round(rating, 2) AS rating
-- FROM parsed
-- WHERE r_now IS NOT NULL
--   AND material = 'glass'                -- PARAM: cell coordinates
--   AND piece_count >= 30
--   AND price BETWEEN 30 AND 50
-- ORDER BY r_now;
--
-- Parse-coverage check (honesty stat for the deck):
--
-- SELECT count(*)                                    AS n_active,
--        count(piece_count)                          AS has_piece_count,
--        count(material)                             AS has_material,
--        count(lid_type)                             AS has_lid,
--        count(form)                                 AS has_form,
--        count(*) FILTER (WHERE piece_count IS NOT NULL
--                          AND material IS NOT NULL
--                          AND price IS NOT NULL)    AS full_cell_assignment,
--        count(*) FILTER (WHERE r_mid IS NOT NULL)   AS velocity_computable
-- FROM parsed WHERE r_now IS NOT NULL;
-- =====================================================================
