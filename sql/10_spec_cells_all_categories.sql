-- =====================================================================
-- 10_spec_cells_all_categories.sql — SPEC CELLS, ALL 7 ROADMAP CATEGORIES,
-- PROFIT-WEIGHTED. Generalizes 09_spec_extractor.sql (Food Storage pilot)
-- into one parameterized pass: swap the PARAM blocks (category id set,
-- margin, token lists, band cutpoints) and rerun per category.
--
-- Cell = dim1 (material/type) x dim2 (piece band / form / oz band) x price band.
-- profit_score = margin * (100*max(velocity,0) + sqrt(30d review gain)) / competitors
--   i.e. the pilot's momentum-per-competitor whitespace score, weighted by
--   the category's historical gross margin so a point of momentum in a
--   52%-margin class outranks the same point in a 40%-margin class.
--
-- ---------------------------------------------------------------------
-- STAGE 0 — margins from shaundatabase.v_so_history (run once, FY2024+):
--
--   SELECT class,
--          round(100*(sum(shipped_dollars)-sum(cogs))
--                /nullif(sum(shipped_dollars),0),1) AS margin_pct
--   FROM shaundatabase.v_so_history
--   WHERE yr >= 2024 AND class IN ('COOKWARE','BAKEWARE','FOOD STORAGE','GADGET')
--   GROUP BY class;
--   -- proxies (no exact class for these 3 roadmap categories):
--   --   hydration  -> class 'PERSONAL BEV'                        (46.3%)
--   --   drinkware  -> class 'TABLETOP', subclass DRINKWARE+BARWARE (52.5%)
--   --   candles    -> class 'HOME FRAGRANCE', subclass FILLED CANDLE (40.5%)
--   -- Fallback rule if a category maps to nothing: 45%. (Not needed —
--   -- every roadmap category mapped to a real class/subclass; see doc.)
--
-- PARAMETER SETS (Amazon region 1; margins are FY2024+ shipped-vs-COGS):
--   Category      cb_category_id  margin  dim2 basis        price cutpoints
--   Cookware      5,35,45         0.397   pc band else form 30/60/100/200
--   Bakeware      2               0.498   form else pc band 15/30/50
--   Food Storage  84              0.457   pc band           15/30/50
--   Gadgets       11,62,68        0.520   form else pc band 10/20/35
--   Hydration     91              0.463   oz band           15/25/40
--   Drinkware     8               0.525   pc band else oz   15/30/50
--   Candles       925             0.405   form else pc band 10/20/35
--
-- CAVEATS (same honesty standards as the pilot):
--  * Cells live WITHIN the top-100 ranked lists only; "competitors = 3"
--    means 3 currently ranked, not 3 on all of Amazon.
--  * piece_count takes the FIRST "N pc/pcs/piece/pack/ct" match; oz takes
--    the first "N oz" match (multi-size titles pick the lead size).
--  * Review-count spikes can be VARIANT MERGES, not sales (seen live:
--    CAROTE +24k, Owala +127k in one window). sqrt() dampens but does not
--    remove this — always Stage-B drill a cell before a buy call.
--  * MATERIALIZED hints keep each run inside the ~60s gateway limit.
--  * Anchor snapshot for the documented run: 2026-07-05.
-- =====================================================================

WITH params AS (
  SELECT
    date '2026-07-05' AS anchor,      -- PARAM: SELECT max(cb_stamp) FROM crystalball.list_item
    14                AS w_recent,
    30                AS w_prev_a,
    44                AS w_prev_b,
    2                 AS min_comp,
    2                 AS min_vel_obs,
    0.397             AS margin       -- PARAM: category margin (see Stage 0 table)
),
lists AS MATERIALIZED (
  -- PARAM: category id set (this default = Cookware 5+35+45)
  SELECT cb_list_id FROM crystalball.list
  WHERE cb_region_id = 1 AND cb_category_id IN (5, 35, 45)
),

-- Windowed per-product metrics (identical to the pilot / 01_breakout_radar)
w AS MATERIALIZED (
  SELECT li.cb_product_id,
    avg(li.cb_rank)  FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                                AS r_now,
    avg(li.cb_rank)  FILTER (WHERE li.cb_stamp BETWEEN p.anchor - p.w_prev_b AND p.anchor - p.w_prev_a) AS r_mid,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp >= p.anchor - 7)                                  AS rev_now,
    max(li.cb_review_count) FILTER (WHERE li.cb_stamp BETWEEN p.anchor - 37 AND p.anchor - 23)          AS rev_prev,
    avg(li.cb_rating) FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                               AS rating,
    avg(li.cb_price)  FILTER (WHERE li.cb_stamp >= p.anchor - p.w_recent)                               AS price
  FROM crystalball.list_item li, params p
  WHERE li.cb_list_id IN (SELECT cb_list_id FROM lists)
    AND li.cb_stamp >= p.anchor - p.w_prev_b
  GROUP BY li.cb_product_id
),

-- Stage A: TITLE -> spec vector. The two CASE blocks below are PARAMS —
-- swap them per category (ready-made blocks in the appendix at the bottom).
parsed AS MATERIALIZED (
  SELECT w.*, pr.cb_asin, t.cb_title,
    COALESCE(
      substring(lower(t.cb_title) FROM '(\d{1,3})[ -]?(?:pcs?|pieces?|packs?|pk|ct|count)\y')::int,
      substring(lower(t.cb_title) FROM '(?:set|pack) of (\d{1,3})')::int)             AS piece_count,
    substring(lower(t.cb_title) FROM '(\d{1,3})\s*(?:oz|ounce)')::int                 AS oz,
    -- PARAM dim1: material/type token list, priority order (Cookware default)
    CASE
      WHEN lower(t.cb_title) ~ 'cast[ -]?iron'               THEN 'cast iron'
      WHEN lower(t.cb_title) ~ 'carbon steel'                THEN 'carbon steel'
      WHEN lower(t.cb_title) ~ '(die[ -]?cast|cast alumin)'  THEN 'cast aluminum'
      WHEN lower(t.cb_title) ~ '(tri[ -]?ply|3[ -]?ply|5[ -]?ply|clad)' THEN 'tri-ply/clad'
      WHEN lower(t.cb_title) ~ 'copper'                      THEN 'copper'
      WHEN lower(t.cb_title) ~ '(granite|stone)'             THEN 'granite/stone'
      WHEN lower(t.cb_title) ~ 'ceramic'                     THEN 'ceramic'
      WHEN lower(t.cb_title) ~ 'anodized'                    THEN 'hard-anodized'
      WHEN lower(t.cb_title) ~ 'stainless'                   THEN 'stainless'
      WHEN lower(t.cb_title) ~ 'non[ -]?stick'               THEN 'nonstick (unspec.)'
    END AS dim1,
    -- PARAM form: category form vocabulary (Cookware default)
    CASE
      WHEN lower(t.cb_title) ~ '(skillet|fry(ing)? pan)'     THEN 'skillet'
      WHEN lower(t.cb_title) ~ 'sauce ?pan'                  THEN 'saucepan'
      WHEN lower(t.cb_title) ~ 'dutch oven'                  THEN 'dutch oven'
      WHEN lower(t.cb_title) ~ '(griddle|grill pan)'         THEN 'griddle/grill'
      WHEN lower(t.cb_title) ~ 'wok'                         THEN 'wok'
      WHEN lower(t.cb_title) ~ 'saut'                        THEN 'saute'
      WHEN lower(t.cb_title) ~ '(stock ?pot|pasta pot)'      THEN 'stockpot'
      WHEN lower(t.cb_title) ~ 'roast'                       THEN 'roaster'
      WHEN lower(t.cb_title) ~ 'braiser'                     THEN 'braiser'
    END AS form
  FROM w
  JOIN crystalball.amz_product     pr ON pr.cb_product_id = w.cb_product_id
  JOIN crystalball.list_item_title t  ON t.cb_title_id    = pr.cb_title_id
),

cells AS (
  SELECT
    dim1,
    -- PARAM dim2: Cookware default = piece band for sets, else form
    CASE WHEN piece_count IS NOT NULL THEN
      'set ' || CASE WHEN piece_count >= 15 THEN '15+' WHEN piece_count >= 10 THEN '10-14'
                     WHEN piece_count >= 5 THEN '5-9' ELSE '2-4' END
    ELSE form END AS dim2,
    -- PARAM price bands: Cookware default cutpoints 30/60/100/200
    CASE WHEN price >= 200 THEN '$200+' WHEN price >= 100 THEN '$100-200'
         WHEN price >= 60 THEN '$60-100' WHEN price >= 30 THEN '$30-60'
         ELSE '<$30' END AS price_band,
    count(*) FILTER (WHERE r_now IS NOT NULL)                       AS competitors,
    round(avg(r_now))                                               AS avg_rank,
    round(avg((-ln(r_now)) - (-ln(r_mid)))::numeric, 3)             AS velocity,      -- F1, cell mean
    count(*) FILTER (WHERE r_now IS NOT NULL AND r_mid IS NOT NULL) AS n_vel,
    sum(rev_now - rev_prev)                                         AS rev_gain_30d,  -- F3, cell sum
    max(rev_now - rev_prev)                                         AS top_rev_gain,
    round(avg(rating)::numeric, 2)                                  AS rating
  FROM parsed
  WHERE dim1 IS NOT NULL AND price IS NOT NULL
    AND (piece_count IS NOT NULL OR form IS NOT NULL)  -- PARAM: dim2 availability guard
  GROUP BY 1, 2, 3
)

-- Profit-weighted ranking. Velocity resting on <min_vel_obs products (or a
-- NULL dim2) gets no score — it still prints for inspection.
SELECT c.dim1, c.dim2, c.price_band,
  c.competitors, c.avg_rank, c.velocity, c.n_vel,
  c.rev_gain_30d, c.top_rev_gain, c.rating,
  CASE WHEN c.n_vel >= p.min_vel_obs AND c.dim2 IS NOT NULL THEN
    round((p.margin * (100 * greatest(c.velocity, 0)
                       + sqrt(greatest(coalesce(c.rev_gain_30d, 0), 0)))
           / c.competitors)::numeric, 1)
  END AS profit_score
FROM cells c, params p
WHERE c.competitors >= p.min_comp
ORDER BY profit_score DESC NULLS LAST, velocity DESC NULLS LAST;

-- =====================================================================
-- APPENDIX A — per-category PARAM blocks (paste over the marked spots).
--
-- BAKEWARE (ids 2, margin 0.498, price cutpoints 15/30/50,
--           dim2 = form first, else 'set ' || band 2-4 / 5-9 / 10+):
--   dim1: silicone | cast iron | carbon steel | aluminized ->'aluminized steel'
--         | stainless | (ceramic|stoneware|porcelain)->'ceramic/stoneware'
--         | glass | alumin->'aluminum' | non[ -]?stick->'nonstick (unspec.)'
--   form: (muffin|cupcake) | (loaf|bread pan) | bundt | springform | cake pan
--         | pizza | (cookie sheet|baking sheet|sheet pan|half sheet|jelly roll)->'sheet pan'
--         | (baking dish|casserole)->'baking dish' | (cooling|wire) rack
--         | ramekin | brownie | baking pan | bakeware set
--
-- FOOD STORAGE (ids 84, margin 0.457, cutpoints 15/30/50, dim2 = pc band
--   1-9 / 10-19 / 20-29 / 30+, require piece_count): reuse the pilot's CASEs
--   verbatim from 09_spec_extractor.sql (ceramic-coated / borosilicate->glass /
--   glass [lids stripped] / stainless / ceramic / silicone / plastic / bamboo).
--
-- GADGETS (ids 11,62,68, margin 0.520, cutpoints 10/20/35,
--          dim2 = form first, else 'set ' || band 2-3 / 4-9 / 10+):
--   dim1: (electric|rechargeable|usb|battery)->'electric' | titanium | stainless
--         | silicone | (bamboo|wood|walnut|acacia|teak)->'wood/bamboo'
--         | (nylon|plastic)->'nylon/plastic' | ceramic | (metal|steel)->'metal (other)'
--   form: (can|jar|bottle) opener->'opener' | (cutting|chopping) board
--         | (mandoline|slicer|chopper|dicer)->'slicer/chopper' | peeler
--         | (spatula|turner) | tongs | whisk | garlic | (scissors|shears)
--         | measuring | thermometer | (grater|zester) | masher
--         | ice (cube|tray|maker|ball)->'ice tray/mold' | (strainer|colander)
--         | (utensil|kitchen tool|gadget)->'utensil set' | spoon rest
--         | splatter | timer | scale
--
-- HYDRATION (ids 91, margin 0.463, cutpoints 15/25/40, dim2 = oz band
--   <20 / 20-31 / 32-40 / 41-63 / 64+; treat titles matching 'gallon'
--   [not 'half gallon'] with no oz as 64oz+):
--   dim1: stainless AND (insulat|vacuum|double[ -]?wall)->'stainless insulated'
--         | stainless | tritan | glass | (insulat|vacuum|double[ -]?wall)->'insulated (unspec.)'
--         | plastic | silicone | bpa[ -]?free->'bpa-free plastic'
--   extras worth keeping as drill columns: straw|chug|spout|handle lid tokens,
--   'time mark|motivational', kids, filter.
--
-- DRINKWARE (ids 8, margin 0.525, cutpoints 15/30/50,
--   dim2 = 'set 2-5 / 6-11 / 12+' from piece_count, else oz single bands
--   <12 / 12-19 / 20+):
--   dim1: double[ -]?wall AND glass->'double-wall glass' | borosilicate->'glass'
--         | crystal | stainless | glass | (ceramic|porcelain|stoneware)->'ceramic'
--         | (acrylic|plastic|tritan)->'plastic/acrylic' | silicone
--   form (drill only): wine | mug | shot | (whiskey|rocks|old fashioned)
--         | beer | can[ -]shaped | tumbler | pitcher | (cocktail|martini|coupe)
--
-- CANDLES (ids 925, margin 0.405, cutpoints 10/20/35,
--   dim2 = form first, else 'multi 2-3 / 4-11 / 12+' or 'single'):
--   dim1: (flameless|led)->'flameless/LED' | warmer
--         | (holder|candlestick|candelabra|sconce)->'holder'
--         | (wax melt|wax cube)->'wax melts' | soy->'soy wax' | beeswax
--         | coconut->'coconut wax' | paraffin | scented->'scented (wax unspec.)'
--         | unscented
--   form: taper | pillar | tea[ -]?light->'tealight' | votive | (jar|tin)->'jar/tin'
--         | wood(en)? wick->'wooden wick'
--
-- APPENDIX B — Stage B drilldown (swap for the final SELECT; name the ASINs
-- behind a hot cell before writing a buy call):
--
--   SELECT cb_asin, left(cb_title, 90) AS title, piece_count, oz, dim1, form,
--          round(price) AS price, round(r_mid) AS rank_prior,
--          round(r_now) AS rank_now, (rev_now - rev_prev) AS rev_gain_30d,
--          round(rating::numeric, 2) AS rating
--   FROM parsed
--   WHERE r_now IS NOT NULL
--     AND dim1 = '<cell dim1>'          -- PARAM: cell coordinates
--     AND price BETWEEN <lo> AND <hi>
--   ORDER BY r_now;
--
-- APPENDIX C — parse coverage (honesty stat, run per category):
--
--   SELECT count(*) AS n_active, count(piece_count) AS has_pieces,
--          count(oz) AS has_oz, count(dim1) AS has_dim1, count(form) AS has_form,
--          count(*) FILTER (WHERE dim1 IS NOT NULL AND price IS NOT NULL
--                     AND (piece_count IS NOT NULL OR form IS NOT NULL)) AS full_cell,
--          count(*) FILTER (WHERE r_mid IS NOT NULL) AS velocity_computable
--   FROM parsed WHERE r_now IS NOT NULL;
-- =====================================================================
