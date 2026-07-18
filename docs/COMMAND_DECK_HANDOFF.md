# Crystal Ball Command Deck — Project Handoff

**Owner:** Brian Melzer (sponsor) → assigned engineer/analyst
**Status:** Sketch v2 (interactive React mockup, illustrative data)
**File:** `crystal-ball-command-deck.jsx` (single-file React component, no external state)
**Date:** July 16, 2026

---

## 1. What this is

A single dashboard ("Command Deck") that turns Crystal Ball's trend signals plus Epoca's own sales data into ranked, actionable merchandising suggestions — and routes every decision into an existing workflow (Crystal Ball Analyzer email or MRF form) at the moment it's made.

Four panels, one composer:

| Panel | Question it answers | Loop stage |
|---|---|---|
| 1. Top 10 Features | What attributes/claims/materials are rising, by category? | Sense |
| 2. Top 10 Trending Products | What product forms are rising, by category? | Sense |
| 3. Add to Our Brand | What should each of our 12 brands add next? | Match → Request |
| 4. Pitch to Retailer | What should we pitch, thought through as **customer → brand → category**? | Match → Shelf |
| Composer (bottom) | Click **+** on any row → builds a prompt → routes to CB Analyzer email or MRF form | Request |

### The two loops (must stay visible in the header)
- **Inner loop** — weekly self-scoring: every prediction is backtested against what actually happened; each row shows a confidence % and the number of scored analogs. Runs in the weekly cbloop job.
- **Outer loop** — the 7-node commercialization wheel (Sense → Match → Request → Source → Decide → Shelf → Read). Node 7 sell-through writeback re-ranks all four panels.

---

## 2. Design decisions already made (don't relitigate without Brian)

1. **Panel 4 thinks in order: customer → brand → category.** Cascading selectors; each level filters the next. A suggestion must make sense for all three simultaneously. An empty result is shown explicitly — it's white space, not a bug.
2. **Categories = Epoca's real top 10 classes by net sales** (2024–YTD 2026, from `epocasql.nsp_summary`, Net Sales = `gross_sales + total_reserve_allow`):
   Cookware $107.7M · Cutlery $24.5M · Coffee $19.9M · Gadget $12.5M · Personal Bev $11.8M · Bakeware $11.6M · Kitchen Electrics $10.7M · Tea $6.5M · Food Storage $5.9M · Popcorn $5.6M. Category chips display $ size.
3. **Brand roster (12, Brian's order):** Epoca, Paris Hilton, Country Living, Cooking Light, Sorelle, Goodful, Tasty, Ecolution, La Mesa, Buen Sazón, Forge & Clad, Von Dutch. Status dot: filled = in market, hollow = pre-launch (currently Sorelle, Buen Sazón, Forge & Clad). Selecting a pre-launch brand in Panel 3 reframes the list as its launch line plan.
4. **Customer→brand map (Panel 4 cascade, level 1→2):**
   - Walmart: Paris Hilton, Forge & Clad, Ecolution, Epoca, Von Dutch
   - Target: Forge & Clad, Goodful, Sorelle, Country Living
   - Ross: Buen Sazón, La Mesa, Ecolution, Epoca
   - Amazon: Von Dutch, Tasty, Goodful, Cooking Light, Paris Hilton
   - Costco: Forge & Clad, Epoca, Cooking Light
5. **Every row carries:** a 3-dot funnel strip (social → search → shelf), momentum %, and inner-loop confidence (`85% · 6` = 85% confidence, 6 scored analogs).
6. **Visual language:** graphite/ink palette with **amber reserved for loop/feedback/confidence elements** (matches the existing AI Loop wheel diagrams). Font: Archivo.
7. **Composer output formats are fixed:**
   - **CB Analyzer email:** To `crystalballapp@epoca.com`, subject **must** be `Task: [best] …`, sent **from Brian's Epoca Outlook, never Gmail**. Body lists concepts with evidence, then chains Analytics (Excel/PPT) + Design (Nano Banana decks/moodboards) in one task.
   - **MRF prefill:** one block per concept — working name, brand, class, target customer, trend evidence, target FOB marked **internal only, strip before factory send**.

---

## 3. What's real vs. illustrative in the sketch

**Real (queried from epocadatalake):**
- The 10 category names and $ sizes (`epocasql.nsp_summary`, year ≥ 2024)
- The brand roster core (`public.brands`; Buen Sazón, Forge & Clad, Von Dutch not yet in that table — add them)
- The email/MRF format rules

**Illustrative (must be replaced by live queries):**
- All row-level data: features, products, concepts, momentum %, confidence scores, funnel stages
- The customer→brand map (encoded from strategy; should become a config table)
- Inner/outer loop header stats (shown as "—" / "backtest pending")

---

## 4. Data wiring spec (production)

All sources are in **epocadatalake** (Postgres, Epoca-CrystalBall connector). Rules: lowercase snake_case, always schema-qualify, no double-quoting, SELECT only. Consult the **epoca-data-dictionary skill (v2.0)** before writing any query.

| Panel | Source | Logic |
|---|---|---|
| P1 Features | `crystalball.amz_search` (298 weekly periods since Oct 2020) + `crystalball.list_item` titles + `crystalball.sm_hashtag` | Extract n-grams/attributes, momentum-score via predictors, map to the 10 classes |
| P2 Products | SearchPredictor output + `crystalball.list_item` review-count velocity (daily snapshots, 1,722 active lists / 848 categories since Aug 2021 — **review velocity is the best demand proxy and currently unused**) | Rank by predicted 6-mo change |
| P3 Brand adds | P1+P2 concepts × brand fit × our POS gap: `shaundatabase.v_amazon_pivot`, `epocasql.walmart_pos`, `sqlmas90` invoice history | Concept trending where we have no SKU under that brand |
| P4 Pitches | Same concepts × retailer shelf gap (`crystalball.wm_list_item` 6.6M rows, Five Below lists, Amazon `list_item`) × customer-brand map × license scope | Strong on Amazon + absent at that retailer + brand fits account |
| Composer sends | Outlook draft via Graph API (CB route) / POST to MRF-to-Quote intake (MRF route) | **Log every send to the callout ledger** — this is the pitch-capture fix (July audit: 0/34 fields populated) |
| Confidence | New prediction ledger (see dependency below) | Backtest hit rate per concept class |

### Hard dependency: the prediction ledger
The confidence scores are decorative until this exists. Predictions currently live only in the app's SQL Server (`AmzSearchPrediction`, `HashtagPrediction`) and are **deleted/repopulated each run** — no history, no scoring. Required:
1. Archive every prediction run into epocadatalake (new table, e.g. `crystalball.prediction_ledger`).
2. Weekly cbloop job scores each prediction when its 12/26-week horizon elapses.
3. Published hit-rate feeds the header and per-row confidence.

---

## 5. Open items / verify before build

- [ ] **Paris Hilton license scope by class** — confirm with Karen which of the 10 classes are covered before PH concepts rank in P3/P4. The cascade should eventually enforce this automatically.
- [ ] Add Buen Sazón, Forge & Clad, Von Dutch (and Sorelle status) to `public.brands` with launch-status field.
- [ ] Customer→brand map: confirm with Mark (Walmart), Julie (Costco), Glen (off-price/Ross) — then move from hardcoded to a config table.
- [ ] MRF intake endpoint + field mapping: Rachel (form owner), Filia/Piyush (engineering).
- [ ] Outlook Graph API draft creation from Brian's Epoca account (CB Analyzer route).
- [ ] Concept entity-resolution: P1/P2 signals and P3/P4 concepts should share IDs (embedding/clustering layer) so a click in any panel references one canonical concept.
- [ ] Decide hosting: internal web app vs. Claude artifact vs. embedded in Crystal Ball 2.0.

## 6. Suggested build order

1. Prediction ledger + backtest (unblocks all confidence scores)
2. P1/P2 live queries against the 10 classes
3. P4 shelf-gap join + cascade config tables
4. Composer → Outlook draft + MRF POST + callout-ledger logging
5. P3 POS-gap scoring
6. Inner/outer loop header stats

**People:** Yerbol (orchestrator/writeback — note: single point of failure, plan a backup), Roberto (MCP/data infra), Filia + Piyush (engineering), Rachel (MRF intake), Carolyn (compliance sign-off on outbound formats), Karen (PH license scope).

---

*Prepared from the v2 sketch conversation, July 16, 2026. The .jsx file is the visual source of truth; this document is the build contract.*
