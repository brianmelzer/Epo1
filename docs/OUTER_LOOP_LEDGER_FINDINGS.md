# Outer-Loop Ledger — Prototype Findings

*Can we actually grade Crystal Ball's call-outs on real commercial outcomes?*
**Yes — validated against `shaundatabase` on 2026-07-02.** This is the evidence
behind Phase 4B of [`CRYSTAL_BALL_LOOP_V2.md`](CRYSTAL_BALL_LOOP_V2.md), and the
queries live in [`../sql/04_outer_loop_ledger.sql`](../sql/04_outer_loop_ledger.sql).

## What's traceable today

The outer loop (call-out → pitch → MRF → price/factory → buy → ship →
sell-through → reorder) is already instrumented in internal data:

| Outer-loop stage | Table(s) | Status |
|---|---|---|
| Sell-through (units, $, COGS, margin) | `v_so_history`, `v_invoice_pivot` | ✅ works |
| Persistence / reorder proxy | `v_so_history` active months; `v_reciepthistory` repeat POs | ✅ works |
| Realized margin vs sourcing PO | `v_invoiceddi_pivot` (sale joined to its PO) | ✅ works (2026-dense) |
| Sourcing / factory / FOB cost | `epraw`, `v_disync`, `v_china_po_upload`, `interskyquote` | ✅ present |
| Forecast (for F15 calibration) | `epocaforecast`, `v_forecast_pivot` | ✅ present |
| **Crystal Ball ranking → internal item** | `asinxref` (cb_asin → item_code) | ✅ works |

## Validated numbers

**Part A — outcome scoring works** (COOKWARE, FY2025+). The cast-aluminum +
ceramic items lead — the exact features Crystal Ball's velocity signal flags as
climbing (see `../sql/02_feature_lift.sql`). External momentum and internal
margin agree:

| Item | Units | Gross $ | Margin | Active months |
|---|---|---|---|---|
| Pioneer Woman CA Double-Burner Griddle | 129,774 | $2.74M | 41% | 18 |
| Pioneer Woman 14pc CA CER Cookware Set | 49,556 | $2.45M | 27% | 10 |
| Pioneer Woman 6Qt Cast-Alum Jumbo Cooker | 91,539 | $2.34M | 46% | 18 |
| Paris Hilton 10pc CA CER Set (heart knob) | 12,218 | $0.89M | 52% | 8 |

**Part B — the bridge is real.** `asinxref` = 516 mappings; **220** of those
ASINs are tracked in Crystal Ball's Amazon rankings; **123** bridged items have
2025+ sales. So for Epoca's own Amazon-listed items we can put external rank
velocity next to realized sell-through and margin in one table.

**Part C — realized margin vs the sourcing PO.** `v_invoiceddi_pivot` ties each
shipped sale to the PO that made it (`po_unit_cost` is text, `$`-prefixed).
Example (2026): PH Travel Laptop Bag sold $16.61 vs PO $7.50 = **55% margin**;
Primula Hand Frother $1.86 vs $1.18 = 37%.

## The one missing piece (the net-new artifact)

Everything above scores *items*. To grade *call-outs*, we need to know **which
item/concept Crystal Ball recommended, when, and to whom** — and that only exists
today inside Librarian PDFs/decks, not as structured data.

**Action:** start a **call-out ledger** — one row per recommendation
(date, retailer, concept/ASIN/item_code, predicted PWS, forecast window). Once it
exists, joining it to Parts A–C yields the full F13 Item Quality Score and lets
F11/F15 retrain the PWS weights on real outcomes. This is the single highest-
leverage thing to start logging now; every cycle it runs, the flywheel compounds.

## Caveats
- Foreign tables (`postgres_fdw`) — filter by class/year; avoid large
  cross-foreign joins.
- `v_invoiceddi_pivot` sale→PO coverage is sparse for 2025 (25 rows) and dense
  for 2026 (1,417); use `v_so_history` COGS for older margin.
- `po_unit_cost` is a `$`-prefixed string — strip before casting.
- The asinxref bridge covers items Epoca *lists on Amazon*; competitor call-outs
  used purely as inspiration are traced by concept/keyword, not ASIN.
