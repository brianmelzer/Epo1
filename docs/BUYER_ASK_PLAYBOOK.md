# Buyer Ask Playbook — closing the pitch-conversion dark spot

*Companion to [`CRYSTAL_BALL_LOOP_V2.md`](CRYSTAL_BALL_LOOP_V2.md) §0/§5A and
[`../data/callout_ledger.csv`](../data/callout_ledger.csv). The outer loop's least-instrumented
hand-off is `call out an item → pitch to buyer → buyer likes it`. This playbook standardizes what
we say at the pitch and what we record after it.*

---

## 1. The one-line buyer ask

Every deck pick ships with exactly one ready-to-say line, in this format:

> **[SKU spec] at $[SRP], MOQ [units], targeting [X]% margin, for [window].**

No pick leaves a deck without one. The spec and SRP are logged in the ledger
(`ask_spec`, `ask_srp` columns) the day the deck is issued, so the ask is versioned with the
prediction and can be graded against what the buyer actually approved.

### The 8 current asks (CB-2026-027 → 034)

| # | Ask line (say it verbatim) |
|---|---|
| CB-2026-027 | 10–11pc cast aluminum PFAS-free ceramic set with detachable handle and induction-ready base at **$129.00**, MOQ 5,000, targeting **40% margin**, for **Spring 2026** floor set. |
| CB-2026-028 | 2pk divided bento, leak-proof BPA-free, airtight lid (borosilicate premium tier) at **$29.99**, MOQ 5,000, targeting **50% margin**, for **Back-to-School 2026**. |
| CB-2026-029 | 3pc PFAS-free ceramic baker + roaster set with bonded cooling rack at **$24.99**, MOQ 5,000, targeting **55% margin**, for **Holiday 2026** floor set. |
| CB-2026-030 | Elements 6pc stainless non-slip gadget set anchored by a Primula Protein hero tool (box shredder or meat chopper) at **$14.98**, MOQ 10,000, targeting **60% margin**, for **Q3 2026** dot-com feature. |
| CB-2026-031 | Paris Hilton 2pk scented soy candle gift set with candle-warmer-lamp attach at **$19.98**, MOQ 10,000, targeting **50% margin**, for **Holiday 2026** gifting. |
| CB-2026-032 | Primula double-wall stainless insulated 2pk gift set, shipper-ready for grocery endcap, at **$19.99**, MOQ 10,000, targeting **55% margin**, for **Fall/Holiday 2026**. |
| CB-2026-033 | Value tri-ply 10pc clad set as the "better" step-up SKU beside the cast-aluminum anchor at **$129.00**, MOQ 2,500 (test SKU), targeting **35% margin**, for **Spring 2026**. |
| CB-2026-034 | Country Living magnetic charcuterie board with detachable handle and acacia/slate accent, gift-boxed, at **$39.00**, MOQ 5,000, targeting **55% margin**, for **Fall/Holiday 2026** hosting season. |

**Where the numbers come from (and what is assumed):**

- **SRP** — the retailer roadmap guardrail stated in each deck's §05
  ("10-pc under $129", "2-pack under $29.99", "3-piece under $24.99", "6-pack under $14.98",
  "2-pack gift set under $19.98", "$19.99 2-pack", "~$39 SRP").
- **Target margin** — per the F14 margin-feasibility logic (`FeasibleMargin = SRP_guardrail −
  f(FOB, MOQ, duty, freight)`), anchored to the realized margin of the internal comparables each
  deck cites: cast-aluminum cookware 41–52% → target 40% (027); PH bento 70% / ledger realized 50%
  → 50% (028); ceramic bakers 62–63% → 55% (029); gadgets 63–65% → 60% (030); PH candles 45–60% →
  50% (031); Primula DW mug 61% over 18 mo → 55% (032); internally unproven tri-ply build → a
  conservative 35% on the test SKU (033); magnetic/charcuterie line 55–60% → 55% (034).
  These are **targets, not quotes** — F14 replaces them with a computed landed-cost prior once the
  sourcing pass runs.
- **MOQ** — *assumption*, not yet computed: 5,000 units baseline for club floor-set SKUs, 10,000
  for opening-price/impulse multipacks, 2,500 for the unproven tri-ply test SKU. Replace with the
  MRF/PO-history figure from `sqlmas90` (F14 input) before the pitch if available.
- **Window** — the ledger `forecast_window` for each callout.

---

## 2. The capture rule

**Who:** the salesperson who made the pitch (not the analyst, not the next refresh — the person
in the room).

**What:** within **1 week** of any pitch of a ledger item, fill three fields on that item's row:

| Field | Values |
|---|---|
| `pitch_date` | date the ask was made (YYYY-MM-DD) |
| `pitch_outcome` | `accepted` / `declined` / `revise` (buyer wants a spec/price change) / `pending` |
| `buyer_accepted` | `yes` / `no` once the outcome is final (`accepted` → yes; `declined` → no) |

**Where:** directly in `data/callout_ledger.csv`, or hand the three values to the weekly Crystal
Ball refresh session and they get entered there. Either path — but within the week, while the
buyer's exact words are still fresh. A `revise` outcome should also update `ask_spec`/`ask_srp`
to what the buyer countered with.

---

## 3. Why this matters

- **`buyer_accepted` is the missing F13 label.** The IQS training score
  (`IQS = a·Pitched + b·BuyerAccepted + c·MarginAchieved + d·SellThrough + e·Reordered`) currently
  has an empty `BuyerAccepted` column for **all 34 rows** — the model is being graded with its
  second-strongest early label blank.
- **F16 says picks die at the pitch.** Funnel attribution can't distinguish "buyer passed" from
  "never really asked" until pitch outcomes are recorded. Every unfilled row is a leak we can't
  locate.
- **10 filled rows make acceptance rate a real KPI.** §9 of the loop doc names *buyer acceptance
  rate, trending up cycle over cycle* as an outer-loop success metric. With even ~10 rows carrying
  `pitch_outcome`, that number exists for the first time — and each subsequent cycle can be
  compared against it. Until then it's a metric with no data underneath it.

*One sentence to remember: no pick leaves without an ask line, and no pitch ends without a row
update.*
