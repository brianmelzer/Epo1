# Closed-Loop SKU Launch Gating System — Architecture & Build Plan

**Audience:** Epoca leadership + future build team
**Status:** Design proposal (pre-implementation)
**Author role:** AI systems architect / product strategist / technical program lead

---

## 1. Executive Summary

You are not actually missing AI. You are missing a **system of record and a decision discipline** for launches. Today the launch process lives in people's heads, scattered spreadsheets, and Helium 10 tabs; decisions are made with inconsistent rigor, and nothing forces a weak idea to die before it consumes budget and inventory.

The fix is a **closed-loop SKU launch gating system**: a stage-gate pipeline where every idea moves through nine gates, each gate has explicit **pass / fail / revise** logic, every decision is logged with the data it was based on, and post-launch actuals are fed back to recalibrate the gates that approved the launch.

The single most important design principle: **this is 80% deterministic workflow + business rules, and 20% AI.** The leverage is in *forcing the gates to exist*, in *standardizing the inputs*, and in *logging every decision* — not in clever models. AI agents are valuable for the messy, judgment-heavy, unstructured-data parts (reading the top-20 search landscape, brand-fit reasoning, summarizing post-launch signal, drafting recommendations). The gate **decisions** themselves should be transparent, auditable rules with human sign-off — not a black box.

The "ultracode army" is therefore a **hybrid system**: a deterministic orchestrator driving a stage-gate state machine, calling a roster of specialized agents (some pure-deterministic calculators, some reasoning-heavy researchers, some hybrid), with humans holding explicit approval authority at the gates that commit money or inventory.

**The three business questions the system answers, in priority order:**
1. **Should we launch this SKU at all?** (gate decision)
2. **If we launch, how much support does it get?** (tiering / budget allocation)
3. **Where does it live in the portfolio?** (brand fit / hero vs. non-hero)

**What I need from you before building anything of substance is in Sections 5–7 and the three appendix lists at the end.** I will not silently guess your thresholds, your margin math, or your brand definitions — those are leadership decisions, and the system is only as good as those rules.

---

## 2. Problem Reframing

### 2.1 The business problem, stated plainly
You launch too many products, support them too thinly, and learn too slowly. The root cause is an **open-loop, intuition-driven process** with no enforced gates, no standardized economics, and no feedback. Symptoms:

- **Over-launching** → marketing budget diluted across too many SKUs; no SKU gets enough fuel to win a category.
- **Undifferentiated support** → hero and non-hero items treated the same; you starve winners and overfeed losers.
- **Premature launches** → products go live before demand and unit economics are validated.
- **Inconsistent modeling** → price, conversion, CPC, ACOS/TACOS, and Amazon rank dynamics are not modeled the same way twice, so launches aren't comparable.
- **Operations divorced from the decision** → MOQ, lead time, weeks-of-cover, OIH, and domestic-vs-DI routing surface *after* commitment, not as gating constraints.
- **Brand ambiguity** → "is this Brand A or Brand B?" is decided ad hoc, creating cannibalization and brand dilution.
- **No closed loop** → post-launch reality never updates the assumptions that approved the launch, so the same forecasting errors repeat.

### 2.2 Why a closed-loop *agentic* system is the right approach
- **Stage-gates impose discipline.** A state machine where "no product skips gates" structurally prevents the over-launching and premature-launch failure modes. This is the core value and it is *not* AI — it's process encoded in software.
- **The closed loop is the moat.** Logging every decision with its inputs, then feeding actuals back to recalibrate thresholds, turns each launch into a training example for the *next* decision. Over 12–24 months this compounds into a genuinely better launch hit-rate — something competitors running on intuition cannot replicate.
- **Agents handle the parts humans do badly or slowly.** Reading 20 competitor listings, estimating review-density and incumbent strength, reconciling Helium 10 vs. Opportunity Explorer demand figures, drafting a brand-fit argument, and summarizing 30/60/90-day signal are exactly the high-volume, judgment-laden, unstructured tasks where reasoning agents add real leverage. Doing this consistently across hundreds of ideas is impossible manually.
- **Agents make the process scalable and consistent.** The same intake agent asks the same questions every time; the same economics agent uses the same formulas; the same QA agent checks the same data-quality rules. Consistency is what makes launches *comparable*, which is what makes the feedback loop meaningful.

**But:** the *decision authority* stays deterministic + human. Agents produce evidence and recommendations; rules and humans make calls at money/inventory-committing gates.

### 2.3 Failure modes the system must prevent
1. **Gate-skipping / pencil-whipping** — someone forces a pet product through. Mitigation: hard state machine, no gate can be marked PASS without required artifacts; overrides require named executive sign-off and are logged as exceptions.
2. **Garbage-in decisions** — confident decisions on bad/stale data. Mitigation: a dedicated Data Validation + QA agent that blocks a gate when inputs are missing, stale, or internally inconsistent.
3. **AI hallucination on numbers** — an LLM "inventing" a demand figure or margin. Mitigation: all hard math is deterministic code; agents cite sources for every figure; numbers without provenance are rejected.
4. **Over-fitting to the last launch** — feedback loop overreacts to one outlier. Mitigation: recalibration requires a minimum sample and human review before thresholds change.
5. **Analysis paralysis** — gates so heavy nothing ships. Mitigation: time-boxed gates, a "fast lane" for low-risk line extensions, and a default-to-kill bias only on the expensive gates.
6. **Cannibalization blindness** — launching a SKU that eats an existing hero. Mitigation: explicit cannibalization gate against the live catalog.
7. **Sunk-cost continuation** — refusing to kill a validated-but-failing launch. Mitigation: the 30/60/90 monitoring gate has a pre-committed kill rule decided *before* launch.
8. **Shadow process** — teams route around the system. Mitigation: budget and PO approval are *tied to* a gate status; no gate, no money.

### 2.4 Success criteria
**Process / adoption (leading):**
- ≥95% of launches pass through the gates with complete decision logs (no shadow launches).
- Median idea→decision cycle time within target (e.g., intake→economics decision in ≤X days — *you set X*).

**Business outcomes (lagging):**
- Higher **launch hit-rate** (% of launches hitting their 90-day target) vs. baseline.
- Lower **wasted spend & dead inventory** ($ of marketing + inventory written off on killed/failed SKUs) vs. baseline.
- Higher **marketing efficiency on winners** (more budget concentrated on hero/scale SKUs; better blended TACOS).
- **Forecast calibration improving over time** — gap between pre-launch forecast and 90-day actual shrinking cohort-over-cohort. This is the proof the loop is closing.

> You cannot measure most of these without a **baseline**. Establishing the baseline (last 12–24 months of launches: what was spent, what survived, what died) is a Phase 0 deliverable and is also one of my top data asks.

---

## 3. Proposed Ultracode Army of Agents

### 3.1 Architecture overview

```
                          ┌─────────────────────────────┐
   Human (PM/Brand/Ops/   │   ORCHESTRATOR / SUPERVISOR  │
   Finance/Exec) <──────► │   (stage-gate state machine) │
        approvals         └──────────────┬──────────────┘
                                          │ routes idea + dossier through gates
        ┌─────────────────────────────────┼───────────────────────────────────┐
        ▼                ▼                 ▼                ▼                    ▼
  ┌───────────┐   ┌────────────┐   ┌────────────┐   ┌─────────────┐   ┌────────────────┐
  │ Data       │   │ Gate       │   │ Simulation │   │ QA /        │   │ Monitoring     │
  │ Validation │   │ Specialist │   │ Agent      │   │ Adversarial │   │ Agent          │
  │ Agent      │   │ Agents     │   │ (Monte     │   │ Reviewer    │   │ (30/60/90)     │
  │            │   │ (G1–G6)    │   │  Carlo)    │   │             │   │                │
  └───────────┘   └────────────┘   └────────────┘   └─────────────┘   └────────────────┘
        │                │                 │                │                    │
        └────────────────┴─────────────────┴────────────────┴────────────────────┘
                                          │
                          ┌───────────────▼────────────────┐
                          │  DECISION LEDGER (system of      │
                          │  record: every input, score,     │
                          │  decision, approver, timestamp)  │
                          └───────────────┬─────────────────┘
                                          │ post-launch actuals
                          ┌───────────────▼─────────────────┐
                          │  FEEDBACK / CALIBRATION AGENT    │
                          │  (updates thresholds & priors)   │
                          └──────────────────────────────────┘
```

**Design conventions used below:**
- **Type** = `Deterministic` (rules/math/SQL, no LLM in the decision path), `Reasoning` (LLM judgment over unstructured data), or `Hybrid`.
- Every agent writes to the **Decision Ledger**. Agents never make irreversible commitments; they produce scored recommendations.
- "PASS/FAIL/REVISE" verdicts are produced by **deterministic rule evaluation** against leadership-defined thresholds; reasoning agents supply the *evidence and estimates* that feed those rules.

---

### 3.2 Control-plane agents

#### Agent 0 — Orchestrator / Supervisor ("The Gatekeeper")
- **Purpose:** Owns the stage-gate state machine. Decides which gate an idea is in, what's required to advance, dispatches the right agents, enforces "no skipping," routes to humans for approval, and records state transitions.
- **Inputs:** Idea dossier state, gate definitions, agent outputs, human approvals.
- **Outputs:** Next-action routing, gate-status updates, the canonical "where is this idea" view, exception flags.
- **Type:** **Deterministic** (this is a workflow engine — Temporal / Prefect / a state machine, *not* an LLM). Putting an LLM in control of money-gating flow is a failure mode, not a feature.
- **Interactions:** Calls every other agent; is the only writer of authoritative gate state.
- **Human approval:** N/A (it *requests* approvals from humans).

#### Agent QA — Adversarial Reviewer ("Red Team")
- **Purpose:** Before any gate verdict is finalized, independently challenges it: Are the inputs sufficient and fresh? Are estimates internally consistent (e.g., does claimed conversion square with category norms)? Is the agent's reasoning sound or is it rationalizing a desired outcome? Catches optimism bias and hallucinated figures.
- **Inputs:** The producing agent's full output + sources + the gate rule.
- **Outputs:** `endorse` / `challenge(reasons)` / `block(missing_data)`; a confidence rating.
- **Type:** **Reasoning** (LLM as skeptic), with deterministic checks bolted on (provenance present? numbers reconcile?).
- **Interactions:** Sits between every specialist agent and the Orchestrator. A `block` halts gate advancement.
- **Human approval:** None to *run*; its challenges escalate to humans.

#### Agent DV — Data Validation Agent
- **Purpose:** The gatekeeper *for data*. Validates that required inputs exist, are within freshness SLAs, pass schema/range checks, and reconcile across sources (e.g., Helium 10 vs. Opportunity Explorer demand within tolerance). Normalizes units (ASP vs. NSP vs. retail) so downstream math is apples-to-apples.
- **Inputs:** All raw data pulls + source metadata (timestamp, source).
- **Outputs:** A validated, normalized **canonical input record**; a data-quality scorecard; hard blocks on bad/missing inputs.
- **Type:** **Deterministic** (schema validation, range/anomaly rules, reconciliation tolerances). A small reasoning component may *explain* a discrepancy, but the block/pass is rule-based.
- **Interactions:** Runs first at most gates; nothing downstream proceeds on data it rejects.
- **Human approval:** None; flags go to a data owner.

---

### 3.3 Gate specialist agents (the nine-stage pipeline)

> Each maps to a workflow stage. Each emits a **gate dossier** + a deterministic PASS/FAIL/REVISE against leadership thresholds.

#### Gate 1 — Idea Intake Agent
- **Purpose:** Capture an idea in a **standardized, structured form** regardless of how it arrived (Slack, exec hunch, supplier pitch, data signal). Enforce completeness; assign a candidate brand and category; dedupe against existing ideas/SKUs; generate the idea's unique ID.
- **Inputs:** Free-text idea, optional links/images, submitter, target brand/category hints.
- **Outputs:** Structured idea record (problem it solves, target customer, proposed brand, category, hypothesized price band, hero-candidate flag), dedupe result.
- **Type:** **Hybrid** — reasoning to extract structure from messy input; deterministic to enforce required fields and dedupe.
- **Interactions:** Feeds Orchestrator → starts the pipeline.
- **Human approval:** Light — a PM confirms the structured record before it consumes downstream agent time.

#### Gate 2 — Demand Validation Agent
- **Purpose:** Quantify real, durable demand. Pull and reconcile Amazon search volume, Helium 10, and Opportunity Explorer; assess trend (growing/flat/declining/seasonal/fad), search-term breadth, and demand stability.
- **Inputs:** Category & seed keywords, Helium 10 export, Opportunity Explorer export, Amazon search demand.
- **Outputs:** Demand size estimate (with range + sources), trend classification, seasonality profile, demand-confidence score; PASS/FAIL/REVISE vs. minimum-demand threshold.
- **Type:** **Hybrid** — deterministic aggregation of figures; reasoning to classify trend/fad and reconcile conflicting sources.
- **Interactions:** DV validates inputs first; QA challenges the estimate; passes to Gate 3.
- **Human approval:** None to advance past G2 (cheap gate); fail/revise is auto.

#### Gate 3 — Competition / Whitespace Validation Agent
- **Purpose:** Read the **top-20 search-result landscape** and judge winnability: incumbent strength, review density/moat, price spread, differentiation whitespace, barrier to rank.
- **Inputs:** Top-20 listings (titles, prices, review counts/ratings, BSR, images), category norms.
- **Outputs:** Competitive-intensity score, review-density/incumbent-moat assessment, identified whitespace (or "red ocean" verdict), differentiation hypothesis; PASS/FAIL/REVISE.
- **Type:** **Reasoning-heavy** — this is genuinely judgment over unstructured listing data, the highest-value AI task in the system.
- **Interactions:** Heavy QA scrutiny (most hallucination-prone gate). Feeds the brand-fit and simulation gates.
- **Human approval:** None to advance; but a "marginal" verdict routes to a category lead for a quick read.

#### Gate 4 — Unit Economics Validation Agent
- **Purpose:** Build the **standardized economics model**: first cost, landed cost, tooling amortization, ASP/NSP/retail, fees, PPC assumptions (CPC/ACOS/TACOS), to contribution margin and payback. This is where consistency matters most — same formulas, every time.
- **Inputs:** First/landed cost, tooling, MOQ, ASP/NSP/retail, fee schedule, PPC/CPC/ACOS/TACOS assumptions, conversion assumption.
- **Outputs:** Full P&L per unit + at-volume, contribution margin, breakeven ACOS/TACOS, payback period, margin-of-safety; PASS/FAIL/REVISE vs. minimum-margin rule.
- **Type:** **Deterministic** — this MUST be transparent, auditable formulas, not an LLM. A reasoning layer may only *flag* implausible assumptions; it never computes the answer.
- **Interactions:** Consumes DV-normalized costs; assumptions can be stress-tested by the Simulation Agent.
- **Human approval:** **Finance sign-off required** if the SKU advances toward a buy — this gate gates *money*.

#### Gate 5 — Operations / Inventory Validation Agent
- **Purpose:** Pressure-test operational feasibility: MOQ vs. forecast, lead time, weeks-of-cover, OIH, domestic-vs-DI routing, cash tied up in inventory, stockout/overstock risk.
- **Inputs:** MOQ, lead time, forecast (from simulation), warehouse/OIH constraints, routing options, cash constraints.
- **Outputs:** Feasibility verdict, recommended initial buy qty, routing recommendation, inventory-risk score, cash-at-risk; PASS/FAIL/REVISE.
- **Type:** **Deterministic** — inventory math and constraint checks. Reasoning only to summarize trade-offs.
- **Interactions:** Uses Simulation forecast; feeds the buy decision.
- **Human approval:** **Ops/Supply-chain sign-off required** before a PO is cut.

#### Gate 6 — Brand Fit / Cannibalization Validation Agent
- **Purpose:** Resolve "Brand A vs. Brand B," confirm portfolio fit, and quantify cannibalization risk against the **live catalog**. Settles hero vs. non-hero positioning.
- **Inputs:** Brand definitions/guidelines (you must provide these), existing catalog & their keywords/positioning, the idea's positioning.
- **Outputs:** Brand assignment + rationale, cannibalization-risk score (which existing SKUs, how much overlap), hero/non-hero recommendation; PASS/FAIL/REVISE.
- **Type:** **Reasoning-heavy** — brand fit is qualitative judgment; cannibalization overlap has a deterministic keyword/category-overlap component.
- **Interactions:** Needs the canonical catalog; feeds tiering/support decision.
- **Human approval:** **Brand leadership sign-off** on brand assignment for hero candidates.

---

### 3.4 Decision-support & feedback agents

#### Agent SIM — Launch Simulation Agent
- **Purpose:** Forward-model the launch: price × conversion × CPC × rank dynamics → units, revenue, spend, rank trajectory, time-to-profitability. Runs **Monte Carlo** over assumption ranges to produce *distributions*, not point estimates, and a P(success) against the 90-day target.
- **Inputs:** Validated demand, competition, economics, ops constraints, launch-support scenarios (budget tiers).
- **Outputs:** Scenario forecasts (units/revenue/spend/rank over time) with confidence bands, P(hit 90-day target), recommended **support tier & budget**, and the **pre-committed kill threshold** for monitoring.
- **Type:** **Hybrid** — deterministic simulation engine; reasoning to select scenarios, interpret results, and recommend a tier.
- **Interactions:** Pulls from G2–G6; its output is central to the launch decision and sets the monitoring gate's kill rule.
- **Human approval:** Reviewed at the launch-decision gate.

#### Agent MON — Post-Launch Monitoring Agent (30/60/90)
- **Purpose:** Track actuals vs. the SIM forecast at 30/60/90 days; detect drift early; compare against the **pre-committed** scale/hold/kill thresholds.
- **Inputs:** Live sales, rank, ACOS/TACOS, conversion, inventory; the original forecast + kill rule.
- **Outputs:** Actual-vs-forecast variance, health status, and a scale/hold/kill recommendation per the pre-set rule.
- **Type:** **Hybrid** — deterministic variance/threshold checks; reasoning to explain *why* (e.g., CPC ran hot vs. conversion underperformed).
- **Interactions:** Feeds the final decision gate and the Feedback Agent.
- **Human approval:** **Scale (more budget/inventory) and Kill both require human sign-off** — money in or write-off out.

#### Agent FB — Feedback / Calibration Agent ("The Loop Closer")
- **Purpose:** The thing that makes it *closed-loop*. Compares forecast vs. actual across launches; identifies systematic bias (e.g., "we overestimate conversion by ~20% in category X"); proposes adjustments to thresholds, priors, and the economics/sim assumptions.
- **Inputs:** Decision Ledger (all past decisions + their inputs) + post-launch actuals.
- **Outputs:** Calibration report, proposed threshold/prior updates, model-drift alerts.
- **Type:** **Hybrid** — deterministic statistics on forecast error; reasoning to hypothesize causes and frame recommendations.
- **Interactions:** Reads the Ledger; proposes changes the Orchestrator applies *only after human approval*.
- **Human approval:** **Required** — threshold changes alter every future decision; never auto-applied. Minimum-sample guard prevents over-fitting to one launch.

---

### 3.5 Cross-cutting: the Decision Ledger (not an agent — the spine)
Append-only, queryable store recording for every idea: every input value + source + timestamp, every agent output + confidence, every gate verdict, every human approver and override, and post-launch actuals. This is the system of record, the audit trail, the training data for the Feedback Agent, and the basis for the success metrics. **If you build only one thing first, build this.**

### 3.6 Agentic vs. deterministic — the explicit split
| Concern | Build as | Why |
|---|---|---|
| Stage-gate flow control | Deterministic state machine | Reliability; never let an LLM gate money |
| Unit economics math | Deterministic code | Auditable, repeatable, must be trusted |
| Inventory/MOQ/cover math | Deterministic code | Hard constraints, not opinions |
| Gate PASS/FAIL verdicts | Deterministic rules over thresholds | Transparent, defensible |
| Data validation/reconciliation | Deterministic | Consistency is the point |
| Demand trend / fad judgment | Reasoning | Unstructured, judgment-laden |
| Top-20 competitive read | Reasoning | Core AI value-add |
| Brand fit | Reasoning | Qualitative |
| Simulation engine | Deterministic core + reasoning wrapper | Math is code; scenario choice is judgment |
| Post-launch "why" narrative | Reasoning | Synthesis |
| Calibration proposals | Hybrid | Stats + hypothesis |

---

## 4. Required Data, Information, and System Inputs

### 4.1 Critical — needed immediately (cannot meaningfully design/build without these)
1. **Leadership thresholds** for each gate (min demand, max competitive intensity, min margin, max ACOS/TACOS at launch, min P(success), inventory limits). *These define the entire decision logic.*
2. **Unit-economics formula + fee schedule** exactly as Finance computes it today (ASP vs. NSP vs. retail definitions, landed-cost components, fee tables, tooling amortization policy).
3. **Brand definitions** — written positioning for each brand (Brand A vs. Brand B vs. …): who it's for, price tiers, category boundaries, what does/doesn't belong. Without this the brand-fit gate is guesswork.
4. **Hero vs. non-hero definition** — the criteria and the support-tier policy (budget bands per tier).
5. **Live catalog export** — all active SKUs with brand, category, keywords, price, margin, BSR — for cannibalization and baseline.
6. **Launch baseline** — last 12–24 months of launches: spend, inventory committed, outcome (survived/scaled/killed). Needed to set success metrics and to seed calibration.
7. **Scale/hold/kill policy** — the pre-committed rules for the 30/60/90 gate.
8. **Approval authority map** — who signs off at each money/inventory/brand gate.

### 4.2 Useful but not mandatory (improves quality, can phase in)
- Helium 10 export format/sample + account access.
- Amazon Product Opportunity Explorer export samples.
- Historical PPC/CPC/ACOS/TACOS by category (to seed sim priors).
- Historical forecast-vs-actual data (accelerates the feedback loop).
- Seasonality data by category.
- Review-density benchmarks by category.
- Domestic-vs-DI routing cost/lead-time tables.

### 4.3 Later-stage — for production implementation
- Live API access: Amazon SP-API/Ads API, Helium 10 API, Opportunity Explorer.
- ERP / inventory system integration (OIH, weeks-of-cover live feeds).
- Data warehouse + the Decision Ledger store.
- SSO/permissions, audit/compliance requirements.
- Tooling/cost master data feeds.

---

## 5. Clarifying Questions

Organized; the **Top 10** are consolidated at the very end.

**On scope & decision rights**
- What's the launch *volume* per quarter the system must handle? (10 ideas or 500?)
- Who has final kill authority, and can the system ever auto-kill, or only recommend?
- Is there appetite for a "fast lane" for low-risk line extensions, or do all ideas take all nine gates?

**On economics**
- Exact definitions: ASP vs. NSP vs. retail vs. landed — show me the formula you trust today.
- What's the minimum contribution margin and max launch ACOS/TACOS that makes a launch "worth it"?
- How is tooling amortized into per-unit economics?

**On demand & competition**
- Which demand source is authoritative when Helium 10 and Opportunity Explorer disagree?
- What demand floor disqualifies an idea outright?
- What signals make a category "unwinnable" (review density? incumbent count? price floor?)?

**On brand & portfolio**
- Give me the written brand definitions — or do they not exist yet? (If not, that's a leadership deliverable, not something AI should invent.)
- What counts as unacceptable cannibalization?
- What separates a hero from a non-hero, concretely?

**On operations**
- Hard inventory/cash limits per launch? Max acceptable weeks-of-cover / OIH?
- Domestic-vs-DI decision rules?

**On the loop**
- What's the 90-day success definition per SKU?
- How much forecast-vs-actual history exists to seed calibration?
- Who approves threshold changes the system proposes?

**On data**
- Do we have API access or only manual exports today?
- Where does the canonical catalog live, and is it clean?

---

## 6. Recommended Phased Build Plan

### Phase 0 — Foundations (weeks 0–4) — *mostly non-AI*
- Lock the **gate thresholds, economics formula, brand definitions, hero policy, kill rules** with leadership (Section 4.1).
- Build the **Decision Ledger** schema + the **stage-gate state machine** (Orchestrator).
- Assemble the **launch baseline** for metrics.
- **Deliverable:** the discipline exists on paper + a skeleton that can move an idea through gates manually.

### v0 — Prototype (weeks 4–8)
- One brand, one category, **manual data entry** (paste Helium 10 / Opportunity Explorer exports).
- Deterministic gates fully working: **Intake, Economics, Ops, gate verdicts, Ledger**.
- First reasoning agents: **Competition (top-20 read)** and **Brand Fit**, with the **Adversarial QA** reviewer.
- A basic **Simulation** (deterministic, point + simple range).
- **Goal:** run 10–20 real ideas through end-to-end; prove the gating *changes decisions*. Fastest path to value.

### v1 — Internal Tool (weeks 8–20)
- Web UI: idea board, gate dossiers, approvals inbox, Ledger views, dashboards.
- **Data Validation Agent** + first **API integrations** (Helium 10, SP-API/Ads) to kill manual entry.
- Full **Monte-Carlo Simulation** with P(success) + support-tier recommendation.
- **Monitoring Agent** wired to live sales/rank; **Feedback Agent v1** producing calibration reports.
- Roll out to all brands; enforce "no budget without a gate status."

### Production-grade (weeks 20+)
- Hardened integrations (ERP/inventory, full Ads/SP-API, Opportunity Explorer), SSO, audit/permissions.
- Feedback loop actually adjusting priors/thresholds (human-approved).
- SLAs, monitoring/observability on the agents themselves, cost controls on LLM usage, regression tests on the deterministic math.
- A/B the system's recommendations vs. human-only on a holdout to *prove* hit-rate lift.

### Team roles needed
- **Product/Program lead** (owns the gates + leadership alignment) — most important role.
- **Backend/workflow engineer** (orchestrator, ledger, integrations).
- **Data engineer** (pipelines, validation, warehouse).
- **AI/agent engineer** (reasoning agents, QA, eval harness).
- **Finance partner** (owns economics rules) + **Brand lead** + **Ops/Supply lead** as the human gate-owners.
- (Later) **Frontend engineer**, **analyst** for calibration.

### Build sequence (one line)
**Thresholds & rules → Ledger → state machine → deterministic gates → reasoning gates + QA → simulation → integrations/UI → monitoring → feedback loop.**

### Fastest path to proving value
Get v0 running on **one brand/category with manual data** and run your *next 10–20 real ideas* through it in parallel with the current process. If the gates kill 3 ideas you'd have launched and concentrate budget on 2 you'd have under-supported, the ROI case is made — *before* you spend on integrations.

---

## 7. Risks and Failure Modes (and mitigations)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Thresholds never agreed → no decision logic | High | Fatal | Phase 0 leadership workshop is a hard gate on the whole project |
| Teams route around the system (shadow launches) | High | High | Tie budget/PO approval to gate status; exec mandate |
| Garbage/stale data → confident bad calls | High | High | Data Validation Agent blocks; freshness SLAs |
| LLM hallucinates numbers | Med | High | All math deterministic; provenance required; QA agent |
| Over-engineering before value proven | Med | Med | v0 manual-data prototype first |
| Over-fitting feedback to one launch | Med | Med | Min-sample guard + human approval on threshold changes |
| Analysis paralysis / too-heavy gates | Med | Med | Time-boxed gates + fast lane for line extensions |
| Integration brittleness (Amazon API changes) | Med | Med | Manual-export fallback always supported |
| Brand definitions don't exist | Med | High | Surface as leadership deliverable; do NOT let AI invent them |
| LLM cost sprawl | Low | Med | Deterministic-first; cache; cheap models for cheap gates |

**Where business rules matter more than AI:** every PASS/FAIL threshold, the economics formula, brand definitions, hero policy, kill rules, and approval authority. The AI is worthless if these are undefined — and dangerous if it's allowed to guess them.

---

## 8. What To Do Next

1. **Book the Phase-0 leadership workshop** to lock thresholds, economics formula, brand definitions, hero policy, kill rules, and approval map. Nothing else should start first.
2. **Send me the three appendix lists below** so I can turn this into a concrete v0 spec + schemas.
3. **Pick the v0 brand/category** and pull the **launch baseline**.
4. I'll then produce: the Decision Ledger schema, the gate-rule spec, the economics-model spec, and the v0 agent prompts/eval harness.

---

## Appendix A — Top 10 Clarifying Questions (answer these first)
1. What are the **pass/fail thresholds** for each gate (demand floor, max competitive intensity, min margin, max launch ACOS/TACOS, min P(success), inventory/cash limits)?
2. What is the **exact unit-economics formula** Finance trusts, including ASP/NSP/retail/landed definitions and tooling amortization?
3. Do **written brand definitions** exist (Brand A vs. B vs. …)? If not, who will write them?
4. What concretely separates a **hero from a non-hero**, and what are the **support-tier budget bands**?
5. What is the **90-day success definition** per SKU, and the **pre-committed scale/hold/kill rules**?
6. Which **demand source is authoritative** when sources disagree, and what demand floor disqualifies an idea?
7. What constitutes **unacceptable cannibalization** against the existing catalog?
8. What are the **hard inventory/cash limits** per launch, and the **domestic-vs-DI** routing rules?
9. **Who has approval authority** at each money/inventory/brand gate, and can the system ever auto-kill?
10. Do we have **API access** to Amazon/Helium 10/Opportunity Explorer today, or only manual exports — and how many ideas/quarter must this handle?

## Appendix B — Top 10 Datasets / Tables / Exports To Get First
1. **Active catalog export** (all live SKUs: brand, category, keywords, price, margin, BSR).
2. **Launch baseline** (last 12–24 months: spend, inventory, outcome per launch).
3. **Unit-economics worksheet** (the actual spreadsheet Finance uses today).
4. **Fee schedule** (Amazon referral/FBA fees by category).
5. **Helium 10 export** (sample + format) for a target category.
6. **Opportunity Explorer export** (sample + format).
7. **Historical PPC data** (CPC/ACOS/TACOS by category).
8. **Forecast-vs-actual history** (any past launch forecasts vs. what happened).
9. **MOQ / lead-time / routing tables** (domestic vs. DI, by supplier/category).
10. **Inventory/OIH/weeks-of-cover** snapshot from the ERP/inventory system.

## Appendix C — Top 5 Decisions Leadership Must Make Before Build Starts
1. **The gate thresholds** (the numeric pass/fail rules for every gate).
2. **The brand definitions and hero-vs-non-hero policy** (incl. support-tier budgets).
3. **The pre-committed scale/hold/kill rules** and the 90-day success definition.
4. **The approval-authority map** and whether the system may ever auto-act vs. recommend-only.
5. **The mandate that budget/POs require a gate status** (kills the shadow-process risk) — plus naming the executive owner of the system.
```
