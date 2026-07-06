# Spec Cells, All 7 Roadmap Categories — Profit-Weighted

**What this is.** The Food Storage spec-cell pilot
([`SPEC_LEVEL_BREAKOUT_FOODSTORAGE.md`](SPEC_LEVEL_BREAKOUT_FOODSTORAGE.md))
extended to all seven roadmap categories, with each cell's
momentum-per-competitor score now **weighted by the category's historical
gross margin** so a hot cell in a 52%-margin class outranks the same heat in a
40%-margin class. Query:
[`../sql/10_spec_cells_all_categories.sql`](../sql/10_spec_cells_all_categories.sql).

**Run:** Amazon region 1, anchor **2026-07-05** (latest `cb_stamp`), windows
14d recent vs 30–44d prior. `profit_score = margin × (100·max(velocity,0) +
√(30d review gain)) / competitors`; velocity in ρ = −ln(rank) units.

**Margins** (FY2024+ `shaundatabase.v_so_history`, shipped $ vs COGS):

| Roadmap category | Class used | Margin | Note |
|---|---|---:|---|
| Cookware (5+35+45) | COOKWARE | **39.7%** | $81.8M base |
| Bakeware (2) | BAKEWARE | **49.8%** | $9.5M |
| Food Storage (84) | FOOD STORAGE | **45.7%** | $4.6M |
| Gadgets (11+62+68) | GADGET | **52.0%** | $9.4M |
| Hydration (91) | PERSONAL BEV *(proxy)* | **46.3%** | $5.9M — water bottles/tumblers ARE this class |
| Drinkware (8) | TABLETOP → DRINKWARE+BARWARE *(proxy)* | **52.5%** | thin base ($0.67M) — treat as indicative |
| Candles (925) | HOME FRAGRANCE → FILLED CANDLE *(proxy)* | **40.5%** | thin base ($0.32M) — treat as indicative |

The planned fallback (45% where no class exists) was **not needed** — every
category mapped to a real class or subclass; the three proxies are disclosed
above. Because scores scale linearly with margin, cross-category comparisons
inherit proxy uncertainty; within-category rankings do not.

**Scope caveats (read first, same as pilot):** cells are computed **within
top-100 ranked lists only**; velocity needs a product in both windows;
`piece_count`/`oz` take the *first* regex match in the title; and — new
lesson from this run — **large review gains can be Amazon variant-merges,
not sales** (CAROTE +24k, Owala +127k in one window). Every call below was
Stage-B drilled to named ASINs; artifacts are flagged where found.

---

## 1. Cookware (ids 5+35+45, margin 39.7%)

**Parse coverage** (1,181 active): pieces 56%, material **76%**, form 37%,
full cell assignment **65%**, velocity computable 53%.

| dim1 | dim2 | Price | Comp | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---|---|---:|---:|
| stainless | set 2-4 | $100-200 | 3 | **+0.689** (2) | +49 (+30) | 4.61 | **10.0** |
| tri-ply/clad | saucepan | <$30 | 3 | +0.323 (2) | +30 (+19) | 4.63 | **5.0** |
| nonstick (unspec.) | set 15+ | $100-200 | 18 | +0.062 (9) | +49,578 (+25,174)* | 4.32 | 5.0* |
| ceramic | skillet | $30-60 | 6 | +0.572 (2) | +56 (+56) | 4.45 | **4.3** |
| stainless | set 10-14 | $100-200 | 7 | +0.346 (5) | +1,022 (+872) | **3.70** | 3.8 |

*\*Artifact: the +49.6k is CAROTE's 26-pc (B0F9WBM8H3, +24,153) and 44-pc
(B0FTTVKMJN, +25,174) — a variant review-merge, not organic volume. Discount
this cell's score.* Also honest: the #1 "stainless set 2-4" cell is
**chafing-dish 4-packs** (Specialty Cookware lists), not pots-and-pans — a
real climb (100→44, 94→54) but a food-service/event call, not core cookware.

**Item calls:**

1. **Tri-ply stainless 1.5–2.5 qt saucepan with lid, PFAS-free claim, $25–30**
   — Idymere 2-pot tri-ply at $29 went **10→5, +19 revs/30d** (B0GRYST1NS);
   new entrant Fyctio 2.5 qt tri-ply w/ steamer debuted at $30 (B0GWHTNZB6,
   rank 83). Only 3 ranked competitors; the "affordable tri-ply single piece"
   shelf is nearly empty below $30.
2. **Ceramic nonstick 10.5–12" skillet, non-toxic story, $35–45** — Caraway's
   10.5" holds the cell at $33–42 climbing 54→28 and 60→36 (B09SRY5HYM,
   B09SS34H3K, +56 revs) while three new ceramic entrants debuted this window
   (GreenPan Nova 12" $60, SENSARTE white-ceramic $44, KOCH CS $40). The
   heat is broad, not one SKU. Undercut Caraway at $35–40.
3. **(Quality-gap, conditional) 10–11 pc stainless set, $100–165** — cell
   velocity +0.35 on 5 products, +1,022 revs/30d, but cell rating **3.70**:
   Cuisinart 11-pc $118 went 17→9; Martha Stewart 10-pc $165 added +872 revs
   (verify — merge-sized) at rank 71. Enter only with a 4.5-rating product;
   the demand is proven, the incumbents are disliked. Note 39.7% class
   margin — the weakest of the seven — so this needs volume to pay.

## 2. Bakeware (id 2, margin 49.8%)

**Parse coverage** (552 active): pieces 55%, material 65%, form 44%, full
cell **52%**, velocity computable 47%.

| dim1 | dim2 | Price | Comp | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---|---|---:|---:|
| glass | set 2-4 | $15-30 | 2 | +0.393 (2) | +76 (+43) | 4.74 | **12.0** |
| nonstick (unspec.) | set 2-4 | <$15 | 3 | +0.531 (2) | +132 (+122) | 4.55 | 10.7* |
| glass | baking dish | $15-30 | 3 | +0.532 (2) | +58 (+54) | **4.87** | **10.1** |
| carbon steel | sheet pan | <$15 | 2 | +0.245 (2) | +227 (+115) | 4.50 | **9.9** |
| nonstick (unspec.) | sheet pan | $15-30 | 4 | +0.052 (3) | +121 (+66) | 4.68 | 2.0 |

*\*Contamination: the "nonstick set 2-4 <$15" cell is **oven liners** (HOTEC
et al.), which parse as nonstick material — real movers (80→28) but a
different product. Disclosed, not called.*

**Item calls:**

1. **3-pc tinted/colored glass mixing-bowl set with lids, $18–28** — Pyrex
   Colors 3-pack went **47→22, +43 revs/30d** (B0BWL3VH3Y) next to the
   classic Pyrex 3-pc at rank 27 ($17, +33). Two ranked competitors, both
   Pyrex — the colored-glass prep trend has no second brand in it. 49.8%
   class margin on a giftable ticket.
2. **Deep 9×13 glass baking dish with lid, ~$20** — Pyrex Deep went
   **55→16, +54 revs/30d** (B09ZLT4FZJ); cell rating 4.87, only 3 ranked
   competitors and the other two are new entrants at ranks 89/99. The
   lidded-deep-casserole spec is the differentiator.
3. **(Volume) 3-pack nonstick carbon-steel baking sheets, $11–14** —
   GoodCook owns the cell: small 3-pack **8→3 (+112)**, standard 3-pack at
   rank 62 (+115), pan+rack at 46 (+77). 2 ranked competitors, +227
   revs/30d. A traffic item at 49.8% margin; win on multipack value.

## 3. Food Storage (id 84, margin 45.7%) — rerun for consistency

**Parse coverage** (530 active): pieces 64%, material 60%, full cell **43%**,
velocity computable 44% — matches the pilot (527 active on the 07-04 anchor).

| dim1 | dim2 | Price | Comp | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---|---|---:|---:|
| ceramic-coated | 10-19 | $50+ | 4 | **+1.095** (3) | +18 (+10) | 4.50 | **13.0** |
| glass | 10-19 | $50+ | 2 | +0.322 (2) | +195 (+133) | 4.34 | **10.5** |
| glass | 20-29 | $15-30 | 3 | +0.189 (3) | +139 (+87) | 4.54 | 4.7 |
| glass | 30+ | $30-50 | 4 | +0.269 (2) | +187 (+114) | 4.54 | 4.6 |
| silicone | 1-9 | <$15 | 4 | +0.219 (2) | +31 (+31) | 4.62 | 3.1 |

The pilot's board reproduces on the new anchor (same #1; ordering of #3/#4
swaps within noise). Profit-weighting (45.7%) doesn't reorder within the
category — it recalibrates it against the other six.

**Item calls (pilot calls re-validated + one new):**

1. **12-pc ceramic-coated glass set, "no PTFE/PFAS" claim, $69–99** — still
   the #1 cell and now the **top profit-weighted cell of all 7 categories**.
   BRIVARA at $209–215 hit **rank 14** (from 52/62); Caraway $125–144; the
   $50–125 gap is still empty. Early-trend margin play (+18 revs/30d only).
2. **30–40 pc borosilicate snap-lid meal-prep set, $39–46** — holds (velocity
   +0.27, +187 revs/30d, 4 competitors).
3. **NEW: 10–18 pc premium glass set at $50–66** — the glass × 10-19 × $50+
   cell appeared this window with only 2 members: Rubbermaid Brilliance 18-pc
   at $66 sits at **rank 2 with +133 revs/30d** (B08BR9HBZ3) and BOROHOUSE
   10-pk debuted at $50 (rank 43, +62, but 4.08 rating). Proof that a $60+
   glass-set ticket converts; a 4.5-rating 12–14 pc at $55–60 splits
   Rubbermaid and the $39 Razab shelf.

## 4. Gadgets (ids 11+62+68, margin 52.0%)

**Parse coverage** (1,323 active): pieces 47%, material 60%, form 53%, full
cell **46%**, velocity computable 48%. Materials are often unstated in gadget
titles — the 'electric' type token recovers part of that.

| dim1 | dim2 | Price | Comp | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---|---|---:|---:|
| electric | set 4-9 | $35+ | 2 | +0.369 (2) | +158 (+82) | 4.61 | **12.9** |
| nylon/plastic | utensil set | <$10 | 2 | +0.433 (2) | +6 (+4) | 4.10 | 11.9* |
| nylon/plastic | ice tray/mold | $35+ | 4 | **+0.570** (2) | +23 (+13) | 4.52 | **8.0** |
| stainless | slicer/chopper | $10-20 | 3 | +0.376 (2) | +53 (+53) | **3.20** | 7.8 |
| silicone | set 10+ | <$10 | 4 | +0.393 (3) | +155 (+53) | 4.20 | 6.7 |

*\*Two-product cell with +6 total reviews — score is velocity on near-zero
volume; not called.*

**Item calls:**

1. **Cordless electric grill-cleaning brush, dual rotating heads, 6-pc
   accessory kit, $35–40** — both cell members climbing: no-name at $35
   went **95→48 (+82 revs/30d)** (B0GL2MB5WF), NeatLt $40 at 56 (+76)
   (B0GQBDQF5R). 2 ranked competitors, 52% class margin, peak-BBQ seasonal.
   The spec that wins: cordless + rotating head + replacement heads included.
2. **Reusable plastic ice cubes, bulk 330–400 ct with scoop, $36–55** — a
   swarm entered straight into the top 30 this window (330-pk rank 19, 400-pk
   27, 380-pk 29, all fresh ASINs, B0GV3V8J75 et al.). Velocity +0.57 but
   review counts still tiny — a 2-week-confirm call: if two of the swarm hold
   top-30, commit; the $35+ ticket at 52% margin is the draw.
3. **Deep-carbonized bamboo cutting-board set with storage stand, $21–30** —
   Astercook went **23→13 with +212 revs/30d** (B0FH6YL3XC) in a 5-competitor
   cell (score 5.4, just below the top 5). The "carbonized/dark bamboo +
   stand" spec is what's moving vs plain boards (John Boos flat at 58).

## 5. Hydration (id 91, margin 46.3% via PERSONAL BEV)

**Parse coverage** (509 active): size (oz/gallon) **87%**, material **85%**,
full cell **76%** — titles here are spec-dense. But velocity computable only
**37%**: this category churns entrants fastest, so cell velocities lean on
the surviving minority.

| dim1 | dim2 | Price | Comp | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---|---|---:|---:|
| stainless insulated | 20-31oz | $25-40 | 26 | **−0.476** (12) | +135,930 (+127,265)* | 4.10 | 6.6* |
| stainless insulated | 32-40oz | $40+ | 15 | −0.134 (3) | +20,105 (+20,011)* | 3.73 | 4.4* |
| glass | 20-31oz | $40+ | 2 | +0.170 (2) | n/a | 4.60 | **3.9** |
| tritan | <20oz | $15-25 | 3 | +0.172 (2) | +52 (+52) | 4.47 | **3.8** |
| stainless insulated | 20-31oz | $15-25 | 19 | +0.122 (9) | +12,998 (+12,776)* | 4.53 | 3.1* |

*\*Artifacts/megabrands: the giant review gains are single Owala or Stanley
ASINs (Owala B0FFTLNC5S +127k = variant consolidation; Stanley IceFlow 2.0
+7.3k). These cells' scores are inflated and their velocities negative or
brand-driven.*

**Item calls:**

1. **Anti-call first (the profit-weight earns its keep here): do NOT enter
   20–31 oz insulated straw bottles.** The top-scored cell is a mirage:
   26 competitors, velocity **−0.48**, and Owala/Stanley hold ranks
   1/2/9/10/14/26 at $19–32 — including sub-$25 Owala FreeSip variants that
   remove the "undercut the brand" angle entirely.
2. **Glass water bottle with integrated filter, 20–23 oz, $40–55** —
   LifeStraw Go Series glass climbed **84→45** (B0GH2RCPKG); only 2 ranked
   competitors (both LifeStraw). A genuinely empty premium niche — glass +
   filtration — but volume is unproven (no review-gain data yet in-window);
   treat as a scout/verify call, not a PO.
3. **Kids tritan leak-proof bottle 2-pack, 14–15 oz, $15–25** — Bentgo Kids
   2-pack went **78→44 (+52 revs/30d)** (B0BY3KKCZL); Hemli's flat square
   14 oz tritan debuted (ranks 50/51). 3 ranked competitors, back-to-school
   timing ahead.

## 6. Drinkware (id 8, margin 52.5% via TABLETOP proxy — thin base, indicative)

**Parse coverage** (235 active — single list, smallest universe; cells are
small, treat scores as directional): pieces 41%, oz 85%, material 79%, full
cell **74%**, velocity computable 45%.

| dim1 | dim2 | Price | Comp | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---|---|---:|---:|
| double-wall glass | set 2-5 | $15-30 | 2 | +0.249 (2) | +35 (+35) | 4.55 | **8.1** |
| glass | set 12+ | $15-30 | 3 | +0.279 (2) | +127 (+68) | 4.70 | **6.9*** |
| crystal | set 6-11 | $15-30 | 2 | −0.147 (2) | +200 (+184) | 4.58 | 3.7 |
| glass | single 20oz+ | $15-30 | 3 | −0.211 (2) | +366 (+286) | 4.43 | 3.3 |
| stainless | single 12-19oz | <$15 | 3 | +0.077 (2) | +102 (+102) | 4.60 | 3.1 |

*\*Contamination: 2 of the 3 "glass set 12+" members are **acrylic** (US
Acrylic tumblers whose titles say "drinking glasses"). The real glass signal
is one SKU — see call 2.*

**Item calls:**

1. **Freezable double-wall beer/pint mug 2-pack (gel-filled), $20–25** —
   Host Freeze went **71→44 (+35 revs/30d)** (B00OJI35GA); the only other
   cell member is Bodum's classic Pavina at rank 98. Summer-seasonal, 2
   ranked competitors, and double-wall glass is the category's top cell.
2. **Hobnail/textured 12-pc glassware set (highball + rocks), $25–30** —
   Moretoes hobnail 12-pc went **83→32, +59 revs/30d, 4.8 rating**
   (B0D82WRJ9V). After removing the acrylic contamination it's effectively
   alone in ranked top-100 at this spec — the vintage-texture trend at a
   set ticket. Strongest clean drinkware call.
3. **(Observation, not a spec call) licensed 40 oz tumblers** — a Silver
   Buffalo swarm (Disney/Sanrio/Pokemon 40 oz, $16–30) debuted across ranks
   28–90, and Simple Modern's 40 oz took 18→8 (+166). The volume is in
   licensing and brand, not in an enterable spec cell.

## 7. Candles (id 925, margin 40.5% via FILLED CANDLE proxy — thin base)

**Parse coverage** (515 active): type/wax **50%**, pieces 25%, form 34%,
velocity computable 33% — the weakest-parsing category (many titles are pure
scent copy: "Vanilla | Lavender | Amber"). Cells require type + price only;
read them as coarser than other categories'.

| dim1 | dim2 | Price | Comp | Velocity (n) | Rev gain 30d (top) | Rating | Score |
|---|---|---|---:|---|---|---:|---:|
| soy wax | jar/tin | $35+ | 4 | +0.237 (3) | +1,791 (+1,733)* | 4.47 | **6.7** |
| soy wax | multi 4-11 | $20-35 | 3 | +0.377 (2) | +86 (+86) | 4.23 | **6.3** |
| scented (unspec.) | jar/tin | $10-20 | 14 | **+0.997** (8) | −1,662* | 4.57 | 2.9 |
| soy wax | jar/tin | $20-35 | 9 | +0.475 (3) | +101 (+67) | 4.46 | 2.6 |
| scented (unspec.) | jar/tin | <$10 | 9 | +0.180 (3) | +184 (+76) | 4.59 | 1.4 |

*\*Two artifacts: M&SENSE's +1,733 looks merge-sized (verify); the −1,662 on
the hottest-velocity cell is new-ASIN review resets — see the Yankee note.*

**Item calls:**

1. **Men's/gift 4-pack soy candle set, ~7-9 oz each, $24–28** — the cleanest
   cell: a "candles for men" 4-pack went **34→22 (+86 revs/30d)**
   (B0CC5Q5QRR) with two more 4-packs behind it (81→59, 87→62) and fresh
   entrants at 69/79/94/99. Giftable, differentiable (scent story), 3 ranked
   competitors with velocity.
2. **XL 3-wick soy jar, 35 oz / 150-hr burn, $30–36** — M&SENSE 35 oz went
   97→77 with +1,733 revs (flag: verify it's not a merge) while Capri Blue
   Volcano holds **rank 13 at $35** and SALT & STONE $46 jumped 81→37: the
   premium-jar ladder is proven at 2 price points. 4 ranked competitors.
3. **(Defensive) don't enter mid-tier scented jars right now** — Yankee
   Candle's relaunched 22 oz "Premium Plant-Based" large jars at **$11–13**
   stormed the shelf this window (8→4, 11→5, 24→5, 74→9, 26→10; cell
   velocity +1.0 on 8 products). That's brand artillery resetting the $10–20
   band, not whitespace; wait for it to settle.

---

## Cross-category profit-weighted leaderboard (top cells, all runs)

| # | Category | Cell | Score | Margin used |
|--:|---|---|---:|---:|
| 1 | Food Storage | ceramic-coated × 10-19 pc × $50+ | **13.0** | 45.7% |
| 2 | Gadgets | electric × set 4-9 × $35+ (grill brush) | 12.9 | 52.0% |
| 3 | Bakeware | glass × set 2-4 × $15-30 (mixing bowls) | 12.0 | 49.8% |
| 4 | Food Storage | glass × 10-19 pc × $50+ | 10.5 | 45.7% |
| 5 | Bakeware | glass × baking dish × $15-30 | 10.1 | 49.8% |
| 6 | Cookware | stainless × set 2-4 × $100-200 (chafing) | 10.0 | 39.7% |
| 7 | Bakeware | carbon steel × sheet pan × <$15 | 9.9 | 49.8% |
| 8 | Drinkware | double-wall glass × set 2-5 × $15-30 | 8.1 | 52.5% |
| 9 | Candles | soy × jar/tin × $35+ | 6.7 | 40.5% |
| 10 | Hydration | glass × 20-31 oz × $40+ (best *clean* hydration cell) | 3.9 | 46.3% |

(Artifact-inflated cells — CAROTE nonstick 15+, Owala/Stanley insulated —
excluded from this board; they're flagged in their sections.)

**Single best profit-weighted item call: the 12-pc ceramic-coated glass food
storage set at $69–99.** Highest clean score (13.0) of all ~400 cells scored
across seven categories, velocity +1.10 sustained across two anchors, only
4 competitors = 2 brands, both priced 2–4× above the target band, and a
completely empty $50–125 shelf. Runner-up if a volume-now play is preferred:
Bakeware's Pyrex-only colored glass mixing-bowl cell (12.0 at 49.8% margin).

## Method notes / reproducibility

- One query per category (7 runs of `10_spec_cells_all_categories.sql` with
  the appendix PARAM blocks), each inside the ~60s gateway limit thanks to
  the MATERIALIZED hints; coverage and Stage-B drilldowns per appendix B/C.
- All ranks quoted are 14-day averages vs the 30–44d prior window;
  "rank_prior = None" in drilldowns means the product wasn't ranked in the
  prior window (new entrant) — it contributes competition/reviews, not
  velocity, exactly as in the pilot.
- Profit weighting changed decisions in two visible places: it demoted
  Cookware's crowded momentum (39.7% margin drags every cookware score) and
  it forced the Hydration anti-call by making us drill a top score that
  turned out to be an Owala review-merge on a fading cell.
