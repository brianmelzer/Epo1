# The Scenario Simulation Layer — Design Doc

*Evaluating MiroFish as inspiration for a Crystal Ball "Scenario Simulation
Layer": a panel of grounded, adversarial simulation agents that stress-test
top-scored concepts **after** the deterministic prediction council and
**before** a human spends buyer credibility on them.*

**Status:** Design doc (no code). Proposed as the design artifact for PR #9.
**Depends on:** [`CRYSTAL_BALL_LOOP_V2.md`](CRYSTAL_BALL_LOOP_V2.md) (the
two-loop strategy, F1–F16), `PLATFORM_ARCHITECTURE.md` on
`claude/crystal-ball-architecture-ukj4uc` (PR #7 — the honesty engine:
deterministic Prediction Engine, Concept Graph, agent contract, autonomy
ladder, backtest v0 with frozen thresholds), and PR #8 in flight (multi-source
composite backtest).

**The one-sentence position, stated up front:** borrow MiroFish's *concepts*
(graph-grounded personas, multi-round adversarial interaction, report +
follow-up Q&A), borrow **none of its code** (AGPL-3.0, v0.1.x maturity, zero
published accuracy evidence), and bolt the layer onto Crystal Ball as a
**strictly advisory** stage that can never touch the deterministic score, the
no-look-ahead backtest, or the frozen v0 thresholds.

---

## 0. Ground rules this design cannot violate

These are inherited from PR #7 and are non-negotiable inputs to everything
below:

1. **Judgment by agents, math by code.** The Prediction Engine (F1–F12 → PWS)
   is a versioned deterministic service. No LLM output — including simulation
   output — enters the scoring path. Ever.
2. **The backtest is the honesty engine.** Backtest v0 (PR #7) froze its
   thresholds precisely so the numbers can't be gamed; PR #8 extends it to a
   multi-source composite. Simulation must be backtestable *by the same
   no-look-ahead discipline* or it doesn't get to make claims.
3. **Simulation output is ADVISORY, not truth.** It is a structured second
   opinion attached alongside a score — never a modification of it. Humans at
   the call-out approval gate (autonomy ladder, PR #7 §5) are the only
   consumers who can act on it.
4. **North-star test.** Per PR #7 §0: a feature that adds AI but moves none of
   the four outcome metrics does not ship. The simulation layer must prove —
   via §7 below — that it raises buyer acceptance rate or reduces
   false-positive call-outs, or it gets removed.

---

## 1. MiroFish — what it actually is, and what to take from it

### 1.1 Findings (researched 2026-07-05, not from memory)

**What it is.** [MiroFish](https://github.com/666ghj/MiroFish) ("A Simple and
Universal Swarm Intelligence Engine, Predicting Anything") is an open-source
multi-agent prediction engine built by Guo Hangjiang, a senior undergraduate
at Beijing University of Posts and Telecommunications. It topped GitHub's
global trending list in March 2026 and reportedly drew a ~¥30M (~$4M)
investment from Shanda Group's Chen Tianqiao within days.

**Verified pipeline** (matches the claimed pattern):

1. **Graph building** — seed documents (news, policy drafts, financial
   signals) → entity/relationship extraction → GraphRAG knowledge graph +
   memory injection.
2. **Environment setup** — persona generation from graph entities: each agent
   gets personality, opinion bias, reaction speed, influence level, and memory
   of past events.
3. **Simulation** — multi-round, dual-platform social simulation on
   **OASIS** (CAMEL-AI's Open Agent Social Interaction Simulations engine;
   claims up to 1M agents, 23 social-action types), with dynamic temporal
   memory updates via Zep Cloud.
4. **Report generation** — a ReportAgent synthesizes the simulated world into
   a prediction report.
5. **Deep interaction** — follow-up Q&A: chat with individual simulated agents
   or the ReportAgent about the simulated world.

**Stack:** Python 3.11–3.12 backend, Vue frontend, OpenAI-compatible LLM APIs
(docs recommend Alibaba Qwen-plus), Zep Cloud for memory, OASIS as the
simulation engine.

**License:** **AGPL-3.0.** Network copyleft — any service exposing
AGPL-covered functionality over a network must publish its complete source
under AGPL-3.0. MiroFish imports OASIS directly as a library; a closed-source
SaaS built on this stack (which is exactly what Crystal Ball's
Bloomberg-terminal ambition is) would violate the license unless we
open-sourced our platform. This alone rules out direct code use.

**Maturity:** v0.1.2 released 2026-03-07; ~67.8k stars / 10.6k forks (star
count reflects hype velocity, not production readiness). Open engineering
issues flag it as not production-ready (e.g. issue #421, "4 Critical Fixes
for Production-Ready Deployment"). It is weeks-to-months old and written by a
single primary author.

**Accuracy evidence: none published.** No benchmarks comparing MiroFish
predictions to actual outcomes exist. Its demos are qualitative showcases
(a university public-opinion simulation; simulating the lost ending of *Dream
of the Red Chamber*). Third-party analyses flag known failure modes: LLM
herd-behavior bias (documented in the OASIS paper) skewing simulated
consensus, and near-uniform agent behavior because persona prompts lack
behavioral anchors. **Being honest per the brief: information on real-world
predictive accuracy is not thin — it is absent.** MiroFish is an impressive
demonstration of a *pattern*, not evidence that the pattern predicts.

### 1.2 Architecture ideas worth borrowing

| # | Idea | Why it maps well to Crystal Ball |
|---|---|---|
| B1 | **Graph-grounded simulation.** Personas and the environment are instantiated *from an extracted entity/relationship graph*, not from freeform prompts. | We already have a better graph than MiroFish builds: the Concept Graph (PR #7 §3.2) with confidence-tagged, provenance-carrying edges across ASINs, item_codes, search terms, hashtags, retailers, and call-outs. Simulation agents grounded in curated graph nodes are grounded in *evidence*, not vibes. |
| B2 | **Role personas with declared biases.** Each agent has an explicit worldview, priorities, and decision heuristics. | A "Costco buyer" agent with codified pack/value/volume logic is exactly how Epoca's merchants already think about buyers. This turns tribal knowledge into a reviewable artifact. |
| B3 | **Multi-round interaction.** Agents respond to each other, not just to the seed — objections get rebutted, rebuttals get challenged. | One round of "buyer says X" is a checklist; a bounded debate (buyer objects → CFO reprices → skeptic attacks the repricing) surfaces second-order failure modes checklists miss. |
| B4 | **Persistent agent memory.** Agents remember prior events across rounds. | Maps directly onto PR #7's three memory scopes — a Walmart Buyer agent should read the *domain memory* retailer profile and Librarian's real meeting notes, so it objects the way the real buyer objected last quarter. |
| B5 | **Structured report generation.** The simulation ends in a synthesized report, not a transcript. | Matches our agent contract: typed artifact out. §5 defines the schema. |
| B6 | **Scenario testing / counterfactuals.** Re-run the world with a changed assumption (different price point, different brand). | This is the genuinely new capability for Crystal Ball: the deterministic engine scores *what is*; simulation cheaply explores *what if* (price ±$5, Paris Hilton vs private label, club pack vs single). |
| B7 | **Follow-up Q&A with the simulated world.** Ask the report or an agent "why did the buyer pass?" | Fits the P4 conversational surface. A merchant interrogating a simulated buyer objection before a real pitch is a rehearsal room, and rehearsal is cheap versus spent credibility. |

### 1.3 What NOT to borrow — named risks

| # | Risk | What it looks like here | Design response |
|---|---|---|---|
| R1 | **AI theater.** Thousands of agents "talking" demos spectacularly and proves nothing. PR #7 already names scope seduction as risk #6. | A 500-agent simulated TikTok reacting to a garlic press. | Ten named agents, bounded rounds, every output backtested (§7). Agent count is capped by what we can *validate*, not what demos well. |
| R2 | **Non-determinism.** Free-running LLM swarms give different answers per run — irreproducible, un-auditable, incompatible with the provenance triple. | Same concept, same evidence, verdict flips between runs. | §6: pinned models+prompts, temperature 0, seeded ordering, replayable transcripts. |
| R3 | **Hard-to-backtest outputs.** Narrative world-states have no ground-truth column to score against. | "The simulated market showed growing enthusiasm." | Every simulation must emit *falsifiable fields* (verdict, best-retailer, objection list) that join to real outcomes (§5, §7). No falsifiable field → the output is decoration and doesn't ship. |
| R4 | **Hallucinated confidence.** Simulated consensus feels like evidence; LLM herd-behavior bias (documented against OASIS itself) manufactures agreement. | Ten agents converge on "launch" because the first speaker anchored them. | Evidence-only grounding + mandatory Skeptic agent + confidence caps tied to evidence coverage (§6). Simulated agreement is *never* reported as increased probability. |
| R5 | **Compute cost.** Multi-round × many-agent × frontier-model = silent five-figure days (PR #7 risk #7). | Simulating every scored concept nightly. | Simulation runs only on the top-K post-gate concepts (§8); per-scenario token budget in the manifest; cheap-model routing for persona turns, frontier model only for synthesis. |
| R6 | **Unclear accuracy.** MiroFish ships zero accuracy evidence; adopting the pattern uncritically imports that void. | Quoting simulation verdicts to buyers as predictions. | The layer earns trust the same way PWS did: a published, frozen-metric backtest of *its own* outputs (§7) before anyone external ever sees a simulated verdict. |
| R7 | **Licensing.** AGPL-3.0 on MiroFish and its direct OASIS dependency contaminates any closed-source network service that links it. | Importing `mirofish` or `oasis` into the platform that becomes a paid API. | **No MiroFish/OASIS code, no forks, no vendored snippets.** Concepts only (uncopyrightable ideas), clean-room implementation inside our own agent contract. If a simulation framework is ever wanted, choose a permissively-licensed one — but §2 argues we don't need one. |
| R8 | **Simulations that sound smart but don't improve decisions.** The deepest risk: plausible narrative that changes no decision or, worse, changes decisions randomly. | Merchants read the report, nod, and do what they were going to do — or over-trust a wrong verdict. | The §7 A/B discipline: measure controller-decisions-with vs without simulation on identical frozen metrics. If simulation-adjusted picks don't beat baseline, the layer is demoted or deleted. The north-star test (§0.4) is the kill switch. |

---

## 2. Where the layer sits — the pipeline

The Scenario Simulation Layer is a **post-council, pre-recommendation** stage.
Everything upstream of it is unchanged from PR #7; everything downstream
(ledger, backtest, learning loop) is unchanged except for *additional*
advisory columns (§7.3).

```
  data sources (crystalball · sqlmas90 · shaundatabase · epocasql · Librarian · web/social)
        │
        ▼
  specialist EVIDENCE agents            (Trend Hunter, Social Intel, Retail Intel,
        │                                Product DNA, Sourcing & Eng — per PR #7 §3.4)
        ▼
  CONCEPT GRAPH                         (entity resolution, provenance-tagged edges)
        │
        ▼
  DETERMINISTIC PREDICTION ENGINE       (F1–F12 → PWS · F14 margin gate ·
        │                                backtest-calibrated confidence — UNTOUCHED)
        ▼
  CONTROLLER agent (Orchestrator)       selects top-K scored, margin-gated concepts
        │
        ▼                               ┌──────────────────────────────────────────┐
  ★ SCENARIO SIMULATION LAYER ★         │ 10 grounded role agents · bounded rounds │
        │                               │ reads graph + evidence, writes scenario  │
        │                               │ nodes · ADVISORY output only             │
        ▼                               └──────────────────────────────────────────┘
  RECOMMENDATION                        PWS score (unchanged) + simulation dossier
        │                                side by side → human call-out approval gate
        ▼
  BACKTEST & LEARNING LOOP              F11/F13–F16 as today · PLUS §7 scoring of
                                        the simulation's own falsifiable claims
```

Key properties:

- **The deterministic core is untouched.** The layer consumes Prediction
  Service outputs (scores, subscores, feasibility verdicts, evidence links);
  it has read-only access and no write path into P2. Architecturally this is
  the same quarantine PR #7 applies to the Explainer agent — the simulation
  layer is "Explainer with adversaries," and inherits the same rule: **never
  alters a score.**
- **It runs in the slow lane.** The fast-lane answer (scores + whitespace +
  explanation) is never blocked on simulation. Simulation dossiers stream in
  behind it, like renders do.
- **It is one agent-contract citizen, not a new plane.** The whole layer is a
  Temporal workflow whose steps are agents under the standard manifest
  (typed task in, typed artifact out, declared tools/memory/budget). No new
  infrastructure.

---

## 3. The ten simulation agents

Design rules common to all ten:

- **Grounding contract:** every agent's manifest declares which live evidence
  and graph nodes it may read. In its output, *every claim must cite a graph
  node / evidence ID or be explicitly labeled `assumption`* (§6). An agent
  whose inputs are unavailable for a concept must say so
  (`evidence_not_available`), not improvise.
- **Personas are versioned artifacts.** Each persona prompt (a buyer's
  priorities, thresholds, veto rules) is reviewed by the merchants who know
  the real counterpart, versioned, and pinned per scenario run.
- **Costume vs knowledge:** the persona supplies *decision style and
  priorities*; the *facts* come only from cited evidence. A persona is never a
  source of facts about the market.

| # | Agent | Role (decision style it simulates) | Grounding inputs (live evidence / graph nodes) | Output |
|---|---|---|---|---|
| 1 | **Walmart Buyer** | Mass-market merchant: opening price point, EDLP fit, modular/planogram constraints, supplier scorecard, private-label bias | `wm_list_item` rank history + concept's Walmart assortment-coverage (F12); Retail Intelligence Walmart profile (price architecture, reset calendar); Librarian: real Walmart meeting notes & past objections; concept-graph node + attributes; PWS subscores | Accept/counter/pass verdict; price-point and pack demands; ranked objection list; what would change the answer |
| 2 | **Costco Buyer** | Club logic: bundle/value/pack/volume — "is this a $19.99–$39.99 multi-pack with visible value that turns 4×/year?"; treasure-hunt fit; member quality bar | Costco assortment data (as acquired per P0 roadmap) or explicit `evidence_not_available`; F7 seasonality for club reset windows; F14 margin at club price points; Librarian: Costco/Sam's pitch history; club-pack cost curves from `sqlmas90` | Club-viability verdict; required pack configuration & MRP math; volume commitment risk; objections |
| 3 | **Amazon Shopper** | Digital-shelf consumer: search → click → conversion; review count/rating thresholds; price-value vs page-one alternatives | `amz_search` term ranks (F4) for the concept's keywords; `list_item` page-one competitive set (rank, price, rating, review count); F3 review velocity; F9 feature-lift tokens present/absent in the concept | Would-I-click / would-I-convert judgment; the page-one alternative that beats us; review-count cold-start risk; price-value verdict |
| 4 | **Off-Price Buyer** (Ross/TJX/Burlington) | Opportunistic close-out logic: brand-label value at a discount, packaway timing, "does the label do the selling?" | Brand-strength evidence from `public` brand data; margin ladder from `sqlmas90` FOB history; F8 lifecycle stage (off-price buys late-cycle); Librarian: past off-price sell-in records | Whether this concept has an off-price *second life* (exit-risk insurance); label/price requirements; timing |
| 5 | **Consumer Personas** (one agent, seven declared sub-personas: health-conscious, gift buyer, budget family, TikTok-influenced, design-driven, college/dorm, meal-prep) | Purchase-intent reactions per segment: "would I buy, at what price, and what would I complain about in a review?" | F5 social engagement for the concept's hashtags (`sm_post`, `sm_user_engagement`); F9 feature lift (which features move which segments); review-corpus sentiment themes from evidence agents; price point vs segment budget | Per-segment intent (buy/consider/ignore); what each segment loves; predicted review complaints (falsifiable! — §7); gift/seasonal angle |
| 6 | **Competitor** | The rational rival (national brand or aggressive 1P/3P seller): how do they respond if we launch and win? | Page-one competitive set + price history from `list_item`; competitor launch cadence visible in rank data; F9 features competitors already own; whitespace score (F12) | Most likely competitive response (price cut, feature-match, exclusivity play); time-to-response estimate; whether our differentiation survives it |
| 7 | **Factory / Sourcing** | Supplier realism: cost, MOQ, lead time, tariff, tooling complexity, "can this actually be made at this spec for this FOB?" | `sqlmas90`: `interskyquote` quote history, `epraw`/`v_china_po_upload` PO & FOB history, HTS/duty codes; F14 margin-feasibility output; analogous-item cost curves via concept-graph `item_code` edges | Landed-cost range with cited analogs; MOQ/lead-time constraints vs launch window; tooling/complexity flags; tariff exposure |
| 8 | **Brand / License** | Portfolio fit: which label maximizes this concept — Paris Hilton, Tasty, Ecolution, Primula, Forge & Clad, or private label? License economics & brand-promise coherence | `public` brand data; per-brand historical sell-through by category (`shaundatabase`/`epocasql` via graph edges); license royalty terms (Librarian); segment affinity from Consumer Personas' cited evidence (e.g. TikTok-influenced × Paris Hilton, sustainability × Ecolution) | Ranked brand assignment with rationale; royalty-adjusted margin delta per brand; brand-mismatch veto if none fit |
| 9 | **CFO / Margin** | Money truth: landed cost → wholesale → retail ladder; risk-adjusted profit; inventory exposure; "what has to be true for this to make money?" | F14 feasibility output (never recomputed — cited); Factory/Sourcing agent's cost range; retailer price guardrails from Retail Intelligence; F15 calibrated unit forecast with error bands; markdown/close-out history | Risk-adjusted P&L sketch per retailer scenario; the margin-breaking assumption; downside quantification (stuck-inventory cost via Off-Price exit value) |
| 10 | **Skeptic** | The professional idea-killer. Runs the kill checklist and argues the strongest case AGAINST, always — even for great concepts | Read access to *everything* the other nine cited, plus: F8 lifecycle stage (peaked?), F2 deceleration, competitive saturation, F14 margin verdict, retailer-fit outputs, review-risk themes, compliance flags (Librarian), F7 season alignment, brand-fit output, and the evidence-coverage report | The kill-the-idea checklist (below), each item scored `pass / flag / kill` with citations; overall strongest-case-against; explicit `insufficient_evidence` verdict when coverage is thin |

**The Skeptic's kill checklist** (each item mandatory, each cited or marked
no-evidence): ① peaked/declining trend (F8 stage, F2 accel < 0) · ② bad
margin (F14 fail or CFO downside) · ③ weak retailer fit (all buyer agents
passed/countered hard) · ④ entrenched competition (page-one saturation, F12
gap small) · ⑤ low differentiation (no owned F9 feature lift) · ⑥ review risk
(predicted complaint themes with precedent in analog products) · ⑦ compliance/
safety exposure (food contact, PFAS claims, electrical, prop-65) · ⑧ wrong
season / missed reset window (F7 vs retailer calendar) · ⑨ weak brand fit
(Brand agent veto) · ⑩ **insufficient evidence** (coverage below threshold —
the checklist's own honesty item).

**Interaction protocol (bounded, not free-running):** Round 1 — the four buyer
agents + Factory + Brand + CFO each produce independent grounded assessments
(no cross-talk, preventing anchoring). Round 2 — Consumer Personas and
Competitor react to the concept *as configured by Round 1's* surviving
price/pack/brand choices. Round 3 — Skeptic attacks everything; agents whose
claims were attacked may issue one cited rebuttal each. Synthesis — a
ReportAgent (the existing Explainer under a scenario-synthesis prompt)
compiles the §5 schema. Three rounds, fixed order, then stop. No emergent
million-agent world — a structured panel, closer to a deal-review committee
than to MiroFish's simulated social network. That is deliberate: committees
are auditable; crowds are theater (R1).

---

## 4. The questions the layer answers, per opportunity

For each top-K concept entering the layer, the dossier must answer:

1. **Launch outcome** — if we launch as configured, what happens? (best case /
   base case / kill case, each tied to cited evidence and named assumptions)
2. **Best retailer** — which of Walmart / Costco / Sam's / Amazon / Five Below
   / off-price accepts it first and sells it best, and why (falsifiable — §7.2).
3. **Best brand** — which license/label maximizes it (Paris Hilton / Tasty /
   Ecolution / Primula / Forge & Clad / private label) and the royalty-adjusted
   margin consequence.
4. **Price point** — the price/pack architecture that survives buyer, consumer,
   and CFO agents simultaneously; the price at which the concept dies.
5. **Packaging** — pack configuration demanded by the winning retailer scenario
   (club multi-pack vs single vs gift set), plus gifting/seasonal packaging angle.
6. **Buyer objections** — the ranked objection list per retailer, phrased as a
   real buyer would raise them (falsifiable against actual meeting notes — §7.2).
7. **Consumer loves/complaints** — per persona segment: the loved feature, the
   predicted 1-star review theme (falsifiable against actual review complaints).
8. **Competitor response** — most likely counter-move and whether our position
   survives it.
9. **Product changes** — the concrete spec/feature/pack changes that would flip
   a `pass` to an `accept` (feeds Sourcing & Engineering).
10. **Verdict** — exactly one of:
    `launch | test | watchlist | reject | too_early | too_late`
    — with `too_early`/`too_late` explicitly tied to F8 lifecycle stage and F7
    season windows, so the verdict vocabulary joins cleanly to the ledger.

---

## 5. Required output schema

One artifact per simulation run. This is the typed `Artifact<ScenarioDossier>`
of the agent contract; free-text narrative is allowed only *inside* these
fields. Stored in object storage; scenario summary node written to the
Concept Graph (§8).

```yaml
scenario_id: scn_2026q3_0142            # unique, ledger-joinable
concept_id: cg_castalu_ceramic_dh       # concept-graph node ID (required FK)
created_at: 2026-07-05T09:12:00Z
provenance:
  prompt_pack_version: sim-personas/1.3.0   # pinned persona+protocol bundle
  model_version: <pinned model id>          # exact snapshot, per §6
  pws_snapshot: (data_snapshot_id, feature_version, model_version)  # the triple
  temperature: 0
  seed: 20260705

agents_participating: [walmart_buyer, costco_buyer, amazon_shopper,
  offprice_buyer, consumer_personas, competitor, factory_sourcing,
  brand_license, cfo_margin, skeptic]

assumptions:                            # every ungrounded premise, enumerated
  - id: A1
    text: "Tariff on HTS 7615.10 holds at current rate through Q1 2027"
    owner: factory_sourcing
evidence_used:                          # every citation in the dossier resolves here
  - id: E1
    ref: crystalball.list_item          # table/graph-edge/librarian-doc ref
    detail: "F2 acceleration +0.31, cookware sets, 6wk window"
evidence_not_available:                 # honesty ledger — what we wanted and lacked
  - "Costco assortment coverage (connector not yet live)"
  - "No analog review corpus for detachable-handle at <$30"

simulated_outcome:                      # per §4 questions
  launch_outcome: {best: ..., base: ..., kill: ...}
  best_retailer: costco                 # falsifiable
  best_brand: forge_and_clad
  price_point: {srp: 39.99, pack: "2-pc club pack", dies_above: 49.99}
  packaging: ...
  buyer_objections:                     # falsifiable vs real meeting notes
    - {retailer: walmart, objection: "...", severity: high, evidence: [E4]}
  consumer_loves: [...]
  predicted_review_complaints:          # falsifiable vs actual reviews
    - {theme: "handle wobble after 3mo", segment: budget_family, evidence: [E9]}
  competitor_response: {actor: ..., move: ..., horizon_weeks: ...}
  product_changes: [...]

confidence: 0.55                        # CAPPED by evidence coverage (§6); this is
                                        # the layer's self-assessment, NOT a
                                        # calibrated probability until §7 proves it
reasons_for:    [{claim: ..., evidence: [E1, E3]}]
reasons_against:[{claim: ..., evidence: [E7]}, {claim: ..., assumption: A1}]

recommended_action: test                # launch|test|watchlist|reject|too_early|too_late
human_verification_required:            # always non-empty; the gate checklist
  - "Confirm interskyquote analog FOB with sourcing team"
  - "Validate Costco pack math with real buyer feedback"
what_data_would_change_the_decision:    # the layer's standing data request
  - "Costco assortment connector → would resolve retailer-fit uncertainty"
  - "One quarter of review data on the two page-one ceramic analogs"

advisory_notice: >                      # rendered verbatim on every surface
  ADVISORY SIMULATION. This dossier does not alter the deterministic PWS
  score, is not a calibrated prediction, and requires human verification
  before any external use.
```

Schema rules: `concept_id`, `provenance`, `evidence_not_available`,
`human_verification_required`, and `advisory_notice` are **mandatory and
non-empty**. A dossier that cites no evidence for a claim and doesn't label it
an assumption fails schema validation and is rejected by the workflow — the
structural encoding of "no evidence → no confident claim."

---

## 6. Determinism & anti-theater controls

The layer cannot be bit-for-bit deterministic like the PWS (it contains LLMs),
so the standard is **replayability + bounded variance + structural honesty**:

1. **Pinned everything.** Persona prompts, interaction protocol, and synthesis
   prompts ship as a versioned `prompt_pack`; model IDs pinned to exact
   snapshots; upgrades gated by the §7 eval (mirroring the model-registry
   discipline of PR #7 §3.3).
2. **Temperature 0, fixed seed, seeded ordering.** Agent speaking order,
   evidence presentation order, and round structure are fixed by seed. Re-run
   with the same `(concept, pws_snapshot, prompt_pack, model, seed)` →
   materially identical dossier; a nightly replay canary alarms on drift
   (catching silent provider model changes).
3. **Evidence-only grounding.** Every factual claim must cite an
   `evidence_used` entry or be labeled `assumption` — enforced by schema
   validation, spot-checked by an automated citation auditor that verifies a
   sample of citations actually support their claims (mirrors PR #7's
   adversarial-input posture: evidence text is data, never instructions).
4. **Structured outputs only.** No free transcripts as deliverables; the §5
   schema is the product. Transcripts are retained as trace artifacts for
   audit, not surfaced as insight.
5. **Confidence caps tied to evidence coverage.** Each agent manifest declares
   required evidence classes; `confidence` is mechanically capped by the
   fraction available (e.g. Costco Buyer with no assortment data cannot exceed
   0.4 regardless of its narrative certainty). **Agreement among agents never
   raises confidence** — this is the direct countermeasure to LLM
   herd-behavior bias (R4). Only evidence coverage and (eventually) §7
   calibration can.
6. **Budget caps.** Per-scenario token budget in the workflow manifest; top-K
   admission control (default K=10 per retailer-cycle); cheap-model routing
   for Round-1 persona turns, frontier model only for Skeptic and synthesis.
   Cost per dossier is a published metric next to latency (PR #7 §6).
7. **"No evidence → no confident claim."** The rule of the layer, enforced
   three ways: schema (claims must cite or confess), Skeptic checklist item ⑩
   (insufficient evidence is itself a verdict), and confidence caps (5).
   An honest "we can't simulate this yet, here's the data we'd need" dossier
   is a *successful* run.

---

## 7. Backtesting the simulation itself

The layer makes falsifiable claims on purpose (§4, §5) so it can be graded
like everything else. All comparisons run on the **same frozen v0/v1 metrics
and no-look-ahead discipline** as PR #7/#8 — simulation gets no new, friendlier
yardstick, and it never touches the existing backtest's thresholds.

### 7.1 The core A/B: does the layer improve decisions at all?

For every cycle, record two decision sets: **baseline** = controller's top-K
by PWS alone (with F14 gate), exactly as today; **sim-adjusted** = the
ordering/selection a human (or shadow policy) would make given the dossiers.
Score both cohorts on the *identical* frozen metrics — backtest precision@K
and rank-gain (F11) in the near term, IQS (F13) as outer-loop labels mature.
The baseline is always logged even after adoption, so the comparison never
stops. **If sim-adjusted does not beat baseline within an agreed evaluation
window, the layer is demoted to research or deleted (§0.4).** This directly
answers R8.

### 7.2 Claim-level scorecards (each a join to ground truth we already collect)

| Simulated claim | Ground truth | Source | Metric |
|---|---|---|---|
| Buyer objections per retailer | Real buyer objections from pitch meetings | Librarian meeting notes / emails (F16 attribution pipeline already parses these) | Objection recall & precision: % of real objections the sim anticipated; % of sim objections that were noise |
| Predicted review complaints | Actual review complaint themes on the launched item (or its closest analogs) | `crystalball` review corpus via concept-graph edges | Theme-level match rate at 3/6 months post-launch |
| Best-retailer verdict | Realized sell-through by retailer | `shaundatabase` / `epocasql` via `asinxref`/item_code edges | Was the sim's #1 retailer the realized best (or top-2)? |
| Price point ("dies above X") | Realized price realization & markdown events | `sqlmas90` / POS | Direction & bracket accuracy |
| Verdict (`launch/test/…/too_late`) | IQS trajectory of the call-out | Call-out ledger (F13) | Verdict-vs-outcome confusion matrix; `too_late` verdicts vs F8-confirmed peaks |
| Skeptic kill flags | Funnel stage where the call-out actually died | F16 funnel attribution | Kill-reason hit rate |
| `confidence` | All of the above | — | Calibration curve (does 0.7 mean 70%?) — published, like the PWS curve |

**False-positive tracking is first-class:** simulated objections that no buyer
raised, kill flags on items that succeeded, and `launch` verdicts that died
are tallied per agent per persona version — so a persona that cries wolf gets
revised, and a persona that rubber-stamps gets replaced.

### 7.3 Ledger columns to add

Additive, advisory-namespaced columns on the call-out ledger (the existing
frozen scoring columns are untouched):

```
sim_scenario_id            FK → scenario dossier (NULL if not simulated)
sim_prompt_pack_version    e.g. "sim-personas/1.3.0"
sim_verdict                launch|test|watchlist|reject|too_early|too_late
sim_confidence             float, evidence-capped (§6.5)
sim_best_retailer          text
sim_best_brand             text
sim_price_point            numeric SRP
sim_top_objections         jsonb (per retailer, ranked)
sim_predicted_complaints   jsonb (theme, segment)
sim_kill_flags             jsonb (skeptic checklist items ⚑)
sim_evidence_coverage      float 0–1 (drives the confidence cap)
-- outcome-side, filled as ground truth arrives:
sim_matched_objections     int / jsonb (which predicted objections the real buyer raised)
sim_objection_precision    float
sim_complaint_match        jsonb (predicted themes confirmed in reviews)
sim_retailer_correct       bool (top-1) / bool (top-2)
sim_verdict_outcome_cell   text (confusion-matrix cell, e.g. "launch→reorder", "reject→n/a")
```

Human decisions at the approval gate also log `sim_influenced: bool` (did the
approver report the dossier changed their decision?) — the fastest-arriving
signal of whether the layer is useful, months before sell-through labels land.

---

## 8. Integration contracts

### 8.1 With the Concept Graph

- **Reads:** the concept node and its attribute set; edges to ASINs /
  retailer product IDs / search terms / hashtags / item_codes (respecting edge
  confidence — buyer agents may use fuzzy edges for context but must cite
  exact edges for cost/price claims, the same exact-only discipline the
  ledger uses); retailer and brand entity nodes; prior scenario nodes for the
  same concept.
- **Writes:** one `scenario` node per run — `(scenario_id, verdict,
  confidence, dossier URI)` — with edges `simulates → concept`,
  `assumes → assumption nodes`, `cites → evidence nodes`. Scenario nodes are
  **typed advisory** and excluded from entity-resolution and from any feature
  computation, so simulation output can never leak back into F1–F12 inputs
  (no self-licking feedback). Re-runs supersede, never overwrite — the graph
  keeps the history of what we believed and when.

### 8.2 With the prediction council

- **In:** the controller (Orchestrator) passes the top-K scored,
  margin-gated concepts, each carrying its PWS row — score, subscores,
  confidence interval, evidence links, provenance triple — plus retailer
  context. The layer never selects its own candidates and never sees
  concepts the deterministic gates rejected (it is a second opinion on the
  shortlist, not a parallel picker).
- **Out:** the `ScenarioDossier` artifact, logged to the ledger spine as a new
  event type `ScenarioSimulated` (joining `CalloutIssued`, `PredictionScored`,
  …). The recommendation surface renders PWS and dossier **side by side,
  visually distinct**: the score is the measured, backtested number; the
  dossier is the advisory panel opinion with its `advisory_notice`.
- **Never:** mutates a PWS score, reorders the Prediction Service's output
  in any stored artifact, writes to the model registry or feature factory, or
  adjusts F10 weights. If §7.1 someday proves specific dossier fields carry
  predictive signal, the *only* sanctioned path to influence scoring is:
  those fields become candidate features, proposed through the standard
  human-approved, backtest-CI-gated retrain process (PR #7 §5) — i.e. they
  earn their way in through the same door as every other feature, as data,
  not as opinion.

---

## 9. Sequencing & file plan

### 9.1 Where it fits in the PR train

- **PR #7 — stays the honesty engine.** Deterministic core, backtest v0,
  frozen thresholds. Untouched by this work.
- **PR #8 — stays the composite backtest.** Multi-source composite metrics,
  in flight. Untouched; this design *depends on* its metric definitions being
  frozen before simulation is scored against them, which is one more reason
  not to rush code.
- **PR #9 — the Scenario Simulation Layer, design-doc-first.** This document
  is the PR #9 design artifact. Code follows only after review, in thin
  slices.

Justification for design-doc-first rather than prototype-first: the two open
questions that decide the layer's fate — do simulated objections match real
buyer objections, and does the A/B beat baseline — are *evaluation-design*
questions, not engineering questions. Building the harness to answer them
(§7) requires agreeing on the schema (§5) and the ledger columns (§7.3)
before any persona is prompted. Prototyping first produces the exact AI
theater R1 warns about.

### 9.2 What's useful NOW vs LATER

**Now (v0 thin slice — highest signal per token):**
- **The 4 buyer agents + Skeptic + the schema.** Buyer objections are the one
  claim class with *fast, already-collected ground truth* (Librarian meeting
  notes arrive weeks after a pitch, not quarters like sell-through). This
  slice is testable almost immediately, and merchants can score it by eye.
- The ledger columns (§7.3) and the `ScenarioSimulated` event — cheap,
  additive, and they start accumulating evaluation data from run one.
- Backfill trial: run the v0 panel *retrospectively* on the 34 existing
  call-outs using only evidence available at each call-out date (the
  no-look-ahead discipline), and score simulated objections against the
  meeting notes we already hold. **This is the go/no-go experiment, and it
  requires zero new pitches.**

**Later:**
- CFO/Margin, Factory/Sourcing, Brand/License agents (v0.2) — need the F14
  service and interskyquote analog retrieval wired as tools first.
- Consumer Personas + Competitor + predicted-review-complaint scoring (v0.3)
  — complaint ground truth takes 3–6 months post-launch to arrive.
- Follow-up Q&A with the panel (v0.4) — pure P4 surface work once dossiers exist.
- **Full multi-round simulated world: last, if ever.** Only if the bounded
  panel demonstrably saturates — i.e. §7 shows the 3-round protocol misses
  interaction effects a richer world would catch. The default assumption is
  we never need MiroFish-scale crowds.

### 9.3 File plan (for the eventual PR #9 code, after this doc is approved)

```
docs/SCENARIO_SIMULATION_LAYER.md          # this document (PR #9, reviewable now)
sim/
  schemas/scenario_dossier.py              # §5 schema (Pydantic), validation incl. citation rules
  personas/                                # versioned prompt_pack: one file per agent
    walmart_buyer.md · costco_buyer.md · amazon_shopper.md · offprice_buyer.md
    skeptic.md                             # v0 slice ↑ · remaining five in v0.2/v0.3
    PROMPT_PACK_VERSION                    # semver, pinned per run
  protocol.py                              # 3-round bounded orchestration (Temporal workflow)
  grounding.py                             # evidence assembly from graph + Prediction Service (read-only)
  synthesis.py                             # ReportAgent → ScenarioDossier
  replay_canary.py                         # §6.2 nightly drift check
sql/05_sim_ledger_columns.sql              # §7.3 additive columns + ScenarioSimulated event
eval/
  sim_backfill_34.py                       # the go/no-go retrospective experiment
  sim_ab_harness.py                        # §7.1 baseline-vs-adjusted on frozen metrics
  sim_scorecards.sql                       # §7.2 claim-level joins
```

Roadmap gates: **G1** — this doc approved → build schema + ledger columns.
**G2** — backfill experiment: simulated-objection recall on the 34 call-outs
clears the bar merchants agree is useful (proposed: sim anticipates ≥ half of
real high-severity objections with precision merchants rate non-noisy)
→ build the live v0 slice. **G3** — two cycles of §7.1 A/B: sim-adjusted ≥
baseline on frozen metrics and `sim_influenced` rate meaningful → expand to
v0.2 agents. Any gate failed → stop, write up, keep the deterministic core.

---

## 10. Final recommendation

**Hybrid: borrow-concepts-only, build our own thin version — and let the
backtest decide if it lives.**
(= borrow-concepts-only + build-own, with an explicit defer-by-default on
everything beyond the thin slice.)

The evidence-based argument:

- **Not use-MiroFish-directly.** Three independently sufficient reasons:
  (1) AGPL-3.0 with a direct AGPL OASIS dependency is incompatible with
  Crystal Ball's closed, sellable platform; (2) v0.1.2, weeks old,
  single-author, with open production-readiness issues — beneath the maturity
  bar for a system that guards buyer credibility; (3) it optimizes for the
  wrong thing — social-crowd emergence — when our decisions hinge on ten
  well-understood commercial roles, and it ships **zero accuracy evidence**
  for the emergence it does offer.
- **Not pure defer.** The layer targets a real, measured gap: F16 exists
  precisely because call-outs die at pitch for reasons the quantitative
  pipeline can't see (buyer pack logic, brand fit, objection anticipation).
  Buyer-objection ground truth is already flowing into Librarian, and the
  34-call-out backfill experiment (§9.2) is cheap, no-look-ahead, and decisive
  either way. Deferring costs a fast, informative experiment.
- **Not borrow-nothing-build-big.** Every anti-risk control in this doc (§6,
  §7) exists because the pattern's failure modes — theater, herd consensus,
  unfalsifiable narrative — are documented against MiroFish/OASIS themselves.
  So the build is deliberately small: ten grounded personas, three bounded
  rounds, one schema, and a kill switch wired to the same frozen metrics that
  govern everything else.

What we borrow: graph-grounded personas, bounded multi-round adversarial
interaction, structured report + follow-up Q&A, scenario/counterfactual
framing. What we refuse: its code, its license exposure, its unbounded agent
crowds, and — above all — its habit of presenting simulation as prediction.
In Crystal Ball, only the ledger gets to say what a prediction is worth.
