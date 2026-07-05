# Spec-Level Breakout — Food Storage Pilot

**What this is.** Crystal Ball's calls so far were category-level ("glass food
storage is trending"). This pilot moves to **item-spec calls** ("30-pc glass
set, snap-locking lids, $39") by parsing every product title in Amazon Food
Storage into a spec vector and aggregating **spec cells** (material ×
piece-count band × price band) with competition, rank velocity, and 30-day
review gain. Query: [`../sql/09_spec_extractor.sql`](../sql/09_spec_extractor.sql).

**Run:** Amazon Food Storage (`cb_category_id` 84, region 1), anchor
**2026-07-04** (latest `cb_stamp`), windows 14d recent vs 30–44d prior. All
numbers below validated live on that date.

**Scope caveat (read first):** cells are computed **within the top-100 ranked
lists only**. "Competitors = 4" means 4 products *currently ranked*, not 4 on
all of Amazon. Velocity also requires a product to appear in both windows, so
new entrants boost a cell's competition and review numbers but not its
velocity mean.

---

## (a) Parse coverage — honest numbers

Universe: 865 distinct products seen in the category's lists in the last 44
days; **527 currently ranked** (seen in the last 14d) — that's the denominator
that matters for cells.

| Spec field | Parsed (of 527 active) | Coverage |
|---|---|---|
| piece_count | 340 | **65%** |
| material | 318 | **60%** |
| lid_type | 291 | **55%** |
| form | 323 | 61% |
| full cell assignment (pieces + material + price) | 229 | **43%** |
| velocity computable (ranked in both windows) | 233 | 44% |

Where the misses come from, verified by eyeballing titles:

- **Singles don't state a count.** "BRIVARA HOME Ceramic Coated Glass Food
  Storage **Container**" (B0DDV3WCZW, B0DDVFK5CH) has no piece number — 2 of 5
  BRIVARA/Razab-family ASINs miss `piece_count` for this reason.
- **Material is often implied, not stated** (bacon grease jars, brown sugar
  savers, woven baskets) — and the category lists carry genuine contamination
  (juice bottles, syrup pumps, sushi trays, ice scoops ride Food Storage).
- **First-match piece-count ambiguity.** The regex takes the first
  `N pc/pcs/piece/pack` hit. "Dealusy 10 Sets (20-Piece)" correctly parses 20
  (because "10 Sets" doesn't match), but "50 Pack (100-Piece)" parses as 50 —
  defensible (50 sellable units) but not "pieces". A `set/pack of N` fallback
  catches "Razab 16 Pc (Set of 8)" → 16.
- Only cells with a **full** vector enter the table below — 43% of active
  products. The cells are a biased-toward-sets sample, which is fine: sets are
  what a buyer can spec.

## (b) Spec-cell table (top 15 by whitespace score)

`whitespace_score = (100·max(velocity,0) + √(30d review gain)) / competitors`
— hot **and** underoccupied floats up. Cells whose velocity rests on <2
products get no score. Velocity is in ρ = −ln(rank) units (F1); +0.69 ≈ rank
halved.

| Material | Pieces | Price | Competitors | Avg rank | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---:|---|---|---:|---:|
| **ceramic-coated** | 10-19 | $50+ | 4 | 44 | **+1.103** (3) | +18 (+10) | 4.50 | **28.6** |
| **glass** | 20-29 | $15-30 | 3 | 55 | **+0.230** (3) | +130 (+78) | 4.54 | **11.5** |
| **glass** | 30+ | $30-50 | 4 | 29 | **+0.318** (2) | +181 (+109) | 4.54 | **11.3** |
| silicone | 1-9 | <$15 | 4 | 67 | +0.272 (2) | +40 (+31) | 4.63 | 8.4 |
| glass | 20-29 | $30-50 | 4 | 69 | +0.059 (4) | +224 (+130) | 4.58 | 5.2 |
| plastic | 20-29 | $15-30 | 4 | 51 | −0.085 (3) | +215 (+170) | 4.60 | 3.7 |
| glass | 30+ | $50+ | 3 | 47 | +0.029 (2) | +59 (+31) | 4.43 | 3.5 |
| silicone | 1-9 | $30-50 | 5 | 74 | +0.041 (2) | +125 (+73) | 4.78 | 3.1 |
| plastic | 30+ | $15-30 | 10 | 51 | +0.083 (5) | **+435** (+194) | **3.88** | 2.9 |
| glass | 10-19 | $15-30 | 7 | 65 | −0.273 (5) | +351 (+136) | 4.64 | 2.7 |
| plastic | 1-9 | $15-30 | 11 | 60 | +0.013 (7) | +401 (+147) | 4.55 | 1.9 |
| glass | 10-19 | $30-50 | 14 | 49 | −0.002 (10) | +409 (+135) | 4.65 | 1.4 |
| glass | 1-9 | $15-30 | 39 | 68 | −0.076 (26) | +1,347 (+290) | 4.41 | 0.9 |
| glass | 1-9 | <$15 | 15 | 63 | −0.383 (10) | +164 (+54) | 4.14 | 0.9 |
| glass | 1-9 | $30-50 | 28 | 62 | −0.289 (10) | +301 (+87) | 4.52 | 0.6 |

Unscored but notable: **plastic × 10-19 × $30-50** shows velocity +0.959 on a
*single* product (see call #4) — real mover, one-product cell mean.

Read of the board: single-container glass (1-9 pc) is the **crowded, fading**
part of the category (28-39 competitors, negative velocity) — exactly the cell
a category-level "glass is trending" call would have pointed at. The heat is
in **sets** and in **ceramic-coated premium**.

## (c) The item calls

1. **12-pc ceramic-coated glass food storage set, glass lids, "no
   PTFE/PFAS/BPA" claim, $69–99 band** — the #1 cell (velocity **+1.10**, only
   **4 competitors = 2 brands**). BRIVARA HOME sits at $209–221 and jumped
   56→14 and 61→14 in 30 days (B0DDVL2VNB, B0DDV9VYQH); Caraway holds
   $125–147 (14-pc B0BKR4WGFR, 92→59, +10 reviews/30d; new 11-pc Mini
   B0DTM4F8YR just entered at rank 90). **Nothing exists in the cell between
   $50 and $125** — the non-toxic premium story is proven at 2x–4x our target
   price; undercut it. Volume is still small (+18 reviews/30d cell-wide) —
   this is an early-trend margin play, not a volume play.

2. **30–40 pc borosilicate glass meal-prep set, snap-locking lids, $39–46**
   — the Razab cell (velocity +0.32, 4 competitors, +181 reviews/30d). Razab
   30-pc at $39 went 51→19 adding **+109 reviews/30d** (B0CZ4HQT4Y); MCIRCO
   30-pc holds $44 (B095CDXSY5, +67 reviews/30d). Confirmation: two brand-new
   borosilicate entrants debuted *straight into the top 30* this window —
   COOK WITH COLOR 32-pc **with dividers** at $46 (B0DGGG8JCF, rank 16) and
   Canfanni 40-pc at $46 (B0GYPPGSH2, rank 27). Spec the lid as snap/locking
   (both incumbents) and consider dividers as the differentiator the newest
   entrant is winning with.

3. **20-pc glass meal-prep set (10 containers + 10 airtight lids, two sizes),
   $27–29** — glass × 20-29 × $15-30 (velocity +0.23 on all 3 members, +130
   reviews/30d). The mover is Dealusy 20-pc (five 36 oz + five 12 oz) at $28:
   **27→13, +78 reviews/30d** (B0GRTKQBCN). It undercuts the whole 24-pc
   $30-50 shelf (Magic Mill $34, MCIRCO $34, JoyJolt $31 — that adjacent cell
   adds +224 reviews/30d but barely moves, +0.06). The play: 24-pc glass
   snap-lid quality at a sub-$30 ticket. Only 3 ranked competitors.

4. **10-pc large airtight plastic pantry canister set (flour/sugar), $28–35**
   — plastic × 10-19 × $30-50 reads velocity +0.96 but on **one product**, so
   flag it: that product (B0GSWHQ65L, 10-pack flour/sugar canisters, $31) went
   **26→10 with +26 reviews/30d** and only 3 ranked competitors (LocknLock and
   Joseph Joseph sit at ranks 78/86). A one-SKU signal — verify it holds
   another 2 weeks before committing, but rank 10 in Food Storage is not noise.

5. **(Conditional volume play) 40–50 pc leakproof plastic container set,
   $18–25** — plastic × 30+ × $15-30 is the category's biggest volume cell
   (+435 reviews/30d) and its worst-rated (**3.88** avg): the 50-pc $25 leader
   went 11→5 adding +194 reviews/30d (B0GH6S55NG), a 40-pc $18 went 61→40
   (+101, B0D2656Q2Q), and a 62-pc just entered at rank 8 (B0GH7BJB7C). 10
   competitors — crowded — so enter only as a quality-gap play (fix the 3.88
   rating) if the margin math works at $20.

## (d) Validation vs known truths

Both climbers we'd already found by hand land in scored hot cells:

- **Razab 30-pc glass** (B0CZ4HQT4Y): parsed piece_count 30, material glass,
  lid snap/locking, price $39 → **glass × 30+ × $30-50**, the #3 cell (score
  11.3). It *is* the cell's top seller — the cell's `top_rev_gain` of +109 is
  Razab's own number, and its 51→19 (14d-avg) matches the earlier deck's
  61→26 call made from a 2026-07-02 anchor.
- **BRIVARA ceramic-coated** (B0DDVL2VNB, B0DDV9VYQH): parsed ceramic-coated,
  10-pc, $209–221 → **ceramic-coated × 10-19 × $50+**, the **#1 cell** (score
  28.6, velocity +1.10). Note the deck's "$233" was a single-day price; the
  14d average is $221. Two sibling BRIVARA ASINs miss piece_count (not stated
  in title) and fall out of the cell table — parse miss, disclosed above.

The extractor independently rediscovers both manual finds and adds the
context a buyer needs (who else is in the cell, at what price, moving how
fast).

## (e) Extending to other categories

The parser is category-agnostic: `piece_count`, price bands, and lid/form
regexes transfer as-is; only the `lists` CTE (the `cb_category_id`) and the
material vocabulary change (cookware wants `titanium|cast iron|nonstick|
tri-ply`; drinkware wants `insulated|double.wall|tumbler` — lift these from
`02_feature_lift.sql` runs). Next runs in priority order: Cookware Sets (35),
Kitchen Utensils & Gadgets (11), Glassware & Drinkware (8). Walmart works the
same via `wm_list`/`wm_list_item` with the `cb_list_id` map in
[`../sql/README.md`](../sql/README.md), which opens cross-retailer spec-gap
calls ("cell hot on Amazon, empty at Walmart").
