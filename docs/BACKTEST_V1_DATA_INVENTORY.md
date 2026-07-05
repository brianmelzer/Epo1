# Backtest v1 — Data-Source Inventory (multi-source composite)

*Evidence-based inventory of ALL Crystal Ball data sources for backtesting — probed live
against `epocadatalake` on **2026-07-05**. Anchor = `max(cb_stamp)` = **2026-07-03**
(social engagement collected through 2026-07-04). Crystal Ball is **not** velocity-only:
it holds search-intent, social-attention, product-proof, cross-retailer, and internal
commercial data. This doc classifies every source into three groups and states exactly
which strategies (D/E/F) each can power historically.*

Row counts are exact where a full count ran, otherwise `pg_class.reltuples` estimates
(marked ~). All `crystalball` tables carry only PK indexes — time-filtered scans on the
100M+ tables must be bounded by PK range (probes below did this).

---

## Group 1 — HISTORICALLY BACKTESTABLE NOW
*Timestamped history, append-only collection, no look-ahead bias.*

| Source | Table(s) | Rows | Date range | Cadence | Join path | Evidence / probe |
|---|---|---|---|---|---|---|
| **Amazon search ranks** | `crystalball.amz_search` + `amz_term_period` | 6,787,929 | **2020-10-25 → 2026-06-27** | **weekly** — 296 periods, avg span 6.0 days, **0 gaps > 1 day** | `cb_period_id` → `amz_term_period`; term text `ILIKE` `list_item_title.cb_title` → `amz_product` → `list_item` | 10,883–25,000 terms/period (avg 22,932); rank depth top-25,000 (`cb_full_rank` to 281,094); 311,364 distinct terms all-time |
| **Amazon rankings (all 4 list types)** | `crystalball.list_item` (+ `list`, `list_category`, `list_item_title`) | 169.4M (max `cb_item_id` = 169,430,416) | **2021-08-11 → 2026-07-03** | **daily** — 42/42 distinct days in the last-42-day PK slice | `cb_list_id`→`list` (`cb_type_id`, `cb_category_id`, `cb_region_id`), `cb_product_id`→`amz_product`, `cb_title_id`→`list_item_title` | Every row: `cb_rank` (1–100), `cb_rating`, `cb_review_count`, `cb_price`, `cb_stamp` |
| **Amazon New Releases + Most Wished For + Movers & Shakers** (list-type distinction) | same `list_item`, split by `list.cb_type_id` | 3-day slice: BS 179k / NR 91k / MWF 129k rows | all four types since **2021-08-11** (verified in earliest PK slice) | daily | `list.cb_type_id`: **1 = Movers & Shakers** (9 lists), **2 = Best Sellers** (671), **3 = New Releases** (583, 517 active), **4 = Most Wished For** (522, 515 active) — confirmed from `cb_page1_url` patterns (`/gp/new-releases/`, `/gp/most-wished-for/`, `/gp/movers-and-shakers/`); no `list_type` lookup table exists | Recent slice: BS 552 lists / 60,870 products; NR 378 / 31,934; MWF 384 / 39,071 |
| **Product lifecycle** | `crystalball.amz_product` | 3,663,986 | `cb_first_ranking` **2021-08-11 → 2026-07-03**, populated **99.998%** | static attribute, timestamped | `cb_product_id`; `cb_asin` → `shaundatabase.asinxref` (516 rows) → `item_code` | `cb_inception` (listing date) populated 35% (1.28M) — usable where present |
| **Social post ranks** | `crystalball.sm_post_rank` | ~171.6M | **2023-04-07 → 2026-06-26** | **daily** — probe on collection 1: 1,145 distinct days, ~450 ranked posts/day, 14,586 distinct posts | PK (`cb_collection_id`,`cb_post_id`,`cb_date_collected`); `cb_collection_id`→`sm_collection` (hashtag) | Daily top-posts-per-hashtag = attention time series per concept |
| **Social engagement** | `crystalball.sm_user_engagement` | ~175.8M | **2023-04-07 → 2026-07-04** | daily snapshots per tracked post | `cb_post_id`→`sm_post`→`sm_post_rank`/`sm_post_hashtag` | 500k-row slice: views/likes/comments/shares populated **100%**; 285k distinct posts in slice → multiple dated snapshots per post → engagement **velocity** computable |
| **Social posts / captions / creators** | `crystalball.sm_post`, `sm_author`, `sm_post_hashtag`, `sm_hashtag` | 6.33M posts; 2.4M authors; 64.2M post-hashtag rows; 3.65M hashtags | collected **2023-04-07 → 2026-07-04** (published stamps back to 2022-10 and earlier) | continuous | `cb_author_id`→`sm_author`; `sm_post_hashtag` carries `cb_date_published` → hashtag growth series | Captions (`cb_description_str`) populated **100%** (6.33M). Source 1: 3.21M posts / 817k authors; source 127: 3.12M / 1.58M authors. **Creator count** (distinct authors per hashtag per window) computable |
| **Hashtag collections (kitchen-relevant)** | `crystalball.sm_collection` | 815 (all active) | Kitchen & Dining since **2023-04-07** (src 127) / 2023-10-16 (src 1) | daily collection | `cb_hashtag_id`→`sm_hashtag`; `cb_collection_id`→`sm_post_rank` | Groups: **Kitchen & Dining 402**, Home Decor 192 (since 2024-08), "trending" 158 (since 2025-02), other 63. 224+ directly kitchen hashtags (castiron, ceramiccookware, airfryer, bakeware, chefknife, coffeegrinder, …) |
| **Walmart rankings** | `crystalball.wm_list_item` (+ `wm_list`, `wm_product`, `wm_title`) | 7,032,064 | **2025-05-21 → 2026-07-03** (400 distinct days) | daily | `cb_list_id`→`wm_list` (166 lists), `cb_product_id`→`wm_product`, title match for cross-retailer | rank to 120, rating/price per row, `cb_rev_count` on 66% of rows. **Only ~13.5 months — supports ≤ 6–9-mo backtest windows, no full seasonal cycle yet** |
| **Five Below rankings** | `crystalball.f_below_list_item` (+ `f_below_list`, `f_below_list_type`) | 494,440 | **2024-10-29 → 2026-07-03** (562 distinct days) | daily (some gaps) | 10 lists = 5 **Best Seller** + 5 **New Arrivals** (`f_below_list_type`) | rank to 216 with `cb_price`. ~20 months; merchandising buckets, not categories — use as cross-retailer confirmation |
| **Internal outcome labels** (for grading, not predicting) | `epocasql.nsp_summary` (+`nsp_summary2022/23/24`); `epocasql.walmart_pos___omni`; `epocasql.fv_amazon_sales_data`; `shaundatabase.v_so_history` | — (foreign tables; filter tight) | nsp: **yr 2022–2027**, monthly; Walmart POS: **2023–2025**, **weekly** (`wm_week`, pos qty/$, in-stock %, store counts); v_so_history: **yr 2024–2027**, monthly | monthly / weekly | `item_code`; ASIN bridge via `shaundatabase.asinxref` (516 rows, 220 in CB rankings, 123 with 2025+ sales) | Frozen-date safe at month (nsp/v_so) or week (Walmart POS) granularity: include only periods `< T` |

**Backtest window implication:** all Group-1 sources coexist from **Oct 2023 → present
(~33 months)**. Amazon product-proof alone reaches back to **Aug 2021** (4.9 yrs) and
search-intent to **Oct 2020** (5.7 yrs).

---

## Group 2 — LIVE-SIGNAL ONLY FOR NOW
*Exists today but is a current-state snapshot (no change history) or insufficient history —
usable as a filter at scoring time, leaky if treated as historical truth.*

| Source | Table(s) | What exists | Why not backtestable |
|---|---|---|---|
| **Margin / class / brand attributes** | `shaundatabase.v_so_history` attribute columns (`class`, `subclass`, `sub_brand`, `material_desc`, `hts_desc`), `v_item_master` (140+ cols incl. `udf_htc_number`, `udf_duty_rate_pct`, `udf_coo`, `udf_sub_brand`, `product_line`, `suggested_retail_price`, std/avg costs) | Full commercial filter set per item_code | Attributes are **current-state** — no slowly-changing-dimension history. A frozen-date backtest sees *today's* class/cost/duty, not what was true then. Acceptable for class-level filters (classes rarely move); leaky for cost/duty/price-point filters |
| **HTS / Section 232 tariff** | `shaundatabase."232hts"` (22 rows: `hts _code` → `232 section` = steel/aluminum) + `v_item_master.udf_htc_number`, `udf_duty_rate_pct` | Which HTS codes are 232-covered, per-item duty rate | Lookup reflects **today's** 232 scope. Tariff *rates over time* are not captured, so any pre-expansion window gets anachronistic duty status. Fine as a live sourcing gate |
| **Sale→PO realized margin** | `shaundatabase.v_invoiceddi_pivot` | Realized margin vs sourcing PO (`po_unit_cost` is `$`-prefixed text) | Sparse before 2026 (25 rows 2025 vs 1,417 in 2026) — too thin for historical windows |
| **Brand / license fit** | `public.brands`, `licensors`, `products`, `brand_palettes` | Brand/licensor catalog for fit filters | No dated history; current-state filter only |
| **Sentiment / use-case clustering (derived)** | raw `sm_post.cb_description_str` (6.33M captions, 100% populated, timestamped) + review *counts* (not review text) | Raw text is stored **with timestamps**, so an offline NLP pass (sentiment, use-case clusters, caption product-mentions) can be retro-computed **without look-ahead** | **Not precomputed today** — no sentiment/cluster columns exist anywhere. One-off batch job promotes this to Group 1. Note: review *text* is not stored at all, only counts |
| **Hashtag metadata** | `sm_hashtag.cb_description_json` (100% populated) | Descriptive JSON per hashtag | Un-versioned current state |

---

## Group 3 — FUTURE DATA PIPELINE NEEDED
*Not captured anywhere in the lake — confirmed by catalog sweep of all five schemas
(`table_name ~* 'type|trend|reddit|pinterest|google|sentiment|hts|tariff|duty'`): the only
hits were `f_below_list_type`, `shaundatabase.232hts`, `sqlmas90.ar_udt_customer_type`.
No Google Trends, no Reddit, no Pinterest, no media/editorial tables exist.*

| Missing source | Why it matters | Proposed capture (log **weekly**, aligned to `amz_term_period` weeks) |
|---|---|---|
| **Google Trends** | The classic mid-funnel leading indicator between social buzz and Amazon search | For the ~300 tracked concepts/keywords (union of top search terms + collection hashtags + deck concepts): pull weekly relative interest (US, category filters Home & Garden / Food & Drink) via pytrends batch. Schema: `it_google_trends(term text, week_start date, interest_0_100 smallint, region text, category_id int, collected_at timestamptz)` — PK (term, week_start, region, category_id) |
| **Reddit** | Early enthusiast signal (r/castiron, r/cookware, r/BuyItForLife, r/Kitchen_Gadgets) | Weekly per tracked subreddit×keyword: post count, comment count, top-post score. Schema: `it_reddit(subreddit text, keyword text, week_start date, posts int, comments int, top_score int, collected_at timestamptz)` |
| **Pinterest** | Longest-lead visual/aspirational signal for kitchen & home | Pinterest Trends API weekly index per keyword. Schema: `it_pinterest(keyword text, week_start date, trend_index numeric, collected_at timestamptz)` |
| **Media / editorial** | "As seen in NYT Wirecutter/Food52/BuzzFeed" validation moment | Weekly RSS/scrape of ~20 outlets; log (outlet, url, publish_date, matched_keywords[]). Schema: `it_editorial(outlet text, url text, published date, keywords text[], collected_at timestamptz)` |
| **Search query volume** | `amz_search` has **ranks only** — no query counts, impressions, clicks, or conversion. **There is no search→sales conversion proxy in the lake; the closest stand-in is review-count velocity on title-matched products** | If Amazon SQP/Brand Analytics access exists for Epoca's brands, land weekly SQP (query, impressions, clicks, purchases). Otherwise accept rank-only |
| **Social demographics** | `sm_author` holds only name/profile URL — **no demographics anywhere** | If API access permits, log creator follower count + declared geo at collection time: `sm_author_snapshot(author_id, week_start, followers int, geo text)` |
| **Attribute history (SCD)** | Fixes the Group-2 leakage: duty rates, costs, price points as-of a date | Weekly snapshot of `v_item_master` commercial columns + `232hts` into `im_snapshot(item_code, week_start, hts, duty_rate, coo, std_cost, srp, class, sub_brand)` — cheap, immediately makes commercial filters frozen-date-safe |
| **Call-out ledger** | Grading needs *what we recommended, when* | Already begun: `data/callout_ledger.csv` (34 rows). Keep appending; it is the label spine for F13/IQS |

All `it_*` tables: append-only, one row per (entity, week), `collected_at` for audit —
backtestable from day one of capture.

---

## Verdict — which sources can power strategies D / E / F historically

**D — Search-intent (YES, strongest history).** `amz_search` gives 296 **gap-free**
weekly periods (Oct 2020 → Jun 2026), top ~23–25k ranked terms per week. Term-rank
velocity (`-ln(rank)` week-over-week), search breadth (count of related terms matching a
concept), and **emerging terms** (first-ever appearance — e.g. 886 brand-new terms in the
latest week alone) are all computable at any historical freeze date. Keyword→product
matching runs through term text `ILIKE` `list_item_title` (validated pattern in
`sql/03_cross_retailer_gap.sql`). Honest gap: **rank only — no query volume and no
search→sales conversion signal exists**.

**E — Social-attention (YES, from Oct 2023).** Daily post ranks (~171.6M rows) +
engagement snapshots (~175.8M rows, views/likes/comments/shares 100% populated) across
**402 Kitchen & Dining hashtag collections** on two platforms. Hashtag engagement
velocity, creator-count growth (2.4M distinct authors), and caption keyword mentions
(6.33M timestamped captions) are computable historically. Constraints: only backtest a
hashtag **after its `cb_start_to_follow`** (collections were onboarded in waves — Oct 2023,
Aug 2024, Feb 2025 — a curation event, not an organic signal); sentiment/use-case features
need a one-off retro-NLP pass (Group 2); no demographics.

**F — Product-proof (YES, longest and richest).** 169.4M daily rows, Aug 2021 → today:
BSR rank + velocity, review-count growth (best in-lake sales proxy), rating, price — and
the list-type split means **New Releases and Most Wished For lists are separately
backtestable from day one** alongside Best Sellers. Lifecycle stage comes from
`amz_product.cb_first_ranking` (99.998% populated); category competitiveness (product
churn / distinct-product counts per category per window) is directly computable.
Outcome labels join via `asinxref` → `nsp_summary` (monthly, 2022+), `v_so_history`
(monthly, 2024+), and weekly Walmart POS (2023–2025).

**Composite window:** run the D+E+F composite backtest over **Oct 2023 → Jul 2026**
(~33 months, ≥2 full seasonal cycles); run D+F-only variants back to **Aug 2021** for
longer validation. Walmart (`wm_list_item`, May 2025+) and Five Below (Oct 2024+) enter
as confirmation features only inside windows they cover.
