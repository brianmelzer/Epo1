# Crystal Ball Platform Architecture — The Multi-Agent Blueprint

*How Crystal Ball becomes the Bloomberg Terminal for consumer products: an
AI-native platform that predicts winning physical products before retailers,
competitors, or brands see them coming.*

**Role of this document.** [`CRYSTAL_BALL_LOOP_V2.md`](CRYSTAL_BALL_LOOP_V2.md)
is the *strategy* — the two-loop flywheel, the signal formulas (F1–F16), and the
proof they run against live data. This document is the *systems blueprint*: the
architecture that turns that loop into a platform capable of coordinating
hundreds of specialized agents, answering a CEO's question in minutes, and
getting measurably better every cycle. It is written the way a Chief Architect
should write it — challenging the brief where the brief is wrong, and
committing to decisions with reasons.

---

## 0. The north star, stated first

**Crystal Ball's north-star metric is prediction accuracy** — specifically, the
calibrated accuracy of its call-outs measured against *commercial* outcomes
(the F13 Item Quality Score on the call-out ledger), not against marketplace
rank movement, which is only a proxy.

Every feature, agent, and infrastructure choice must improve at least one of
four outcomes, and must say which one and how it will be measured:

| # | Outcome | Metric | Where it's measured |
|---|---|---|---|
| 1 | **Find trends earlier** | Median lead time between our flag and marketplace peak (F6) | Prediction ledger vs `crystalball` rank history |
| 2 | **Predict sell-through more accurately** | Forecast MAPE vs realized units (F15) | Ledger vs `shaundatabase` / `epocasql` |
| 3 | **Shorten product development time** | Cycle latency: question → buyer-ready recommendation | Platform telemetry |
| 4 | **Increase retailer win rate** | Buyer acceptance rate; reorder rate (the strongest signal) | Ledger vs Librarian + `sqlmas90` |

This is the deciding rule for the entire roadmap. A feature that adds AI but
moves none of these four numbers does not ship. The corollary is just as
important: the four outcomes are *lagging* by nature (a reorder takes two
quarters to observe), so the platform must also maintain fast proxies — backtest
precision@K, rank-gain of flagged items — and continuously verify that the
proxies still correlate with the real outcomes.

---

## 1. Chief-Architect review of the brief

The brief is directionally right: multi-agent, event-driven, measurable,
explainable, traceable. Before designing to it, here is where I push back or
extend it. Each of these materially changes the architecture.

### 1.1 "Every major function should be performed by AI agents" — no. Judgment by agents, math by code.

The brief also demands *every prediction is reproducible*. Those two
requirements collide if taken literally: an LLM inside the scoring path makes
scores non-reproducible, non-auditable, and drifty. The resolution:

- **The Prediction Engine is not an agent.** It is a versioned, deterministic
  service: SQL + Python computing F1–F12 features and the composite PWS score,
  pinned to (data snapshot, feature-code version, model-weights version). Same
  inputs, same score, forever. This is what lets us tell a buyer "our hit rate
  is X%" and prove it.
- **Agents surround the engine.** They decide *what to compute* (decompose a
  CEO question), *interpret* results (write the causal "why" a buyer trusts),
  *acquire* new knowledge (research a factory, profile a retailer), and
  *generate* artifacts (decks, renders, briefs). Judgment, language, and
  synthesis are agent work; arithmetic is not.

This split is the single most important line in the architecture. It is also
what the existing Loop 2.0 work already does implicitly — the flywheel refresh
is deliberately "no LLM in the loop" — and it scales: hundreds of agents can
share one trustworthy scoring service.

### 1.2 "Design a multi-agent operating system" — build the contract, not the kernel.

What actually allows "new agents added without changing the architecture" is
not OS-like infrastructure; it is a **stable agent contract**: typed task in,
typed artifact out, declared tools, declared memory scopes, declared evals,
declared escalation rules (§3.4). Gas Town's real lessons apply here and they
are contract lessons, not kernel lessons:

- **Agents coordinate through durable work queues and persistent artifacts,
  not by sharing context windows.** Work sits on a hook; whoever owns the hook
  runs it. Hand-offs are typed artifacts with provenance, so any agent (or
  human) can pick up where another left off.
- **Identity and memory persist across sessions.** An agent's knowledge
  (retailer profiles, factory notes) lives in the knowledge plane, not in a
  conversation.
- **A human overseer role is designed in, not bolted on** — approval gates are
  first-class workflow steps.

Day one, the "OS" is: Temporal (durable workflows + queues) + Postgres (state,
ledger, memory) + object storage (artifacts) + MCP (tool bus). That is enough
for hundreds of agents, because agents are *stateless workers pulling typed
tasks* — scaling them is horizontal and boring, exactly as it should be.

### 1.3 The brief's biggest omission: entity resolution — the concept graph.

The same underlying "thing" appears as an Amazon ASIN, a Walmart item ID, a
Five Below SKU, a TikTok hashtag, an Amazon search term, a WGSN trend name,
and an Epoca `item_code` on a PO. **Nothing in the brief owns joining these.**
Yet every promised capability — leading-indicator cascade, cross-retailer
whitespace, outcome-driven learning — is a *join across identity spaces*. The
flywheel work already hit this wall: two of 26 call-outs score zero because no
internal descriptor matches, and broad regexes over-match
([`FLYWHEEL_AUTOMATION.md`](FLYWHEEL_AUTOMATION.md) §6).

So the architecture adds a **Concept Graph** as a first-class subsystem
(§3.2), and redefines the Product DNA agent as its owner. This is the hardest
data problem in the platform and also its deepest moat: five years of
cross-retailer, cross-social, cross-internal identity mappings is something no
competitor can scrape.

### 1.4 The Learning Agent is starved without a label factory — and n is tiny.

"Continuously retrains scoring models" presumes labels. The repo already built
the right thing — the call-out ledger with F13 IQS labels, refreshed weekly —
but face the number: **34 call-outs**. That is the training set. Consequences
that shape the design:

- Models stay **small and interpretable** (regularized regression for PWS
  weights, per Loop 2.0 §5A) until the ledger grows by an order of magnitude.
  No deep learning on 34 rows, ever.
- The **backtest against marketplace proxies (F11) carries the statistical
  load** meanwhile — there we have 169M ranking rows and can freeze-and-replay
  any historical date.
- **Growing the ledger is a product goal, not a byproduct.** Every deck pick,
  every buyer meeting note in Librarian, every historical PO should be
  back-filled into call-out records. Target: hundreds of labeled call-outs
  within a year.

### 1.5 The Engineering Agent is sequenced wrong: margin feasibility before CAD.

CAD-ready concepts are a Phase-4 luxury. The commercially binding question is
earlier and cheaper: *can we source this to hit the retailer's price point at
target margin?* Epoca's own MRF/PO history (`sqlmas90`: FOB, MOQ, HTS/duty,
freight) answers it (F14). A trend we can't land profitably is a trend we must
not pitch — it spends buyer credibility for nothing. So the brief's Engineering
Agent becomes the **Sourcing & Engineering Agent**, whose v1 deliverable is a
margin-feasibility gate on every recommendation, and whose CAD/factory-brief
capabilities come later.

### 1.6 "Within minutes: renders, factory recs, risk analysis" — two lanes, not one.

A CEO question gets a **fast lane** answer in seconds-to-minutes because
scores, whitespace, and seasonality are *precomputed continuously* — the query
filters a living model (Loop 2.0 idea #8), it does not trigger a batch job. The
**slow lane** — packaging concepts, renders, factory briefs, full decks — runs
async with human approval before anything is customer-facing, and streams in as
it completes. Promising renders "within minutes" synchronously would force
quality compromises for theater.

### 1.7 Missing entirely from the brief; added here.

| Gap | Why it matters | Where addressed |
|---|---|---|
| **Evaluation & calibration harness** | "Every prediction gets a confidence score" is meaningless unless 70% means 70%. Calibration is what buyers ultimately buy. | §3.3, §6 |
| **Data-acquisition governance** | Rankings/social scraping is the platform's oxygen: ToS/legal posture, vendor redundancy, schema-drift alarms, gap backfill. | §3.1, §8 |
| **Cost governance** | Hundreds of agents can silently burn $10k/day. Budgets per question, per agent, per cycle; model routing by task value. | §6 |
| **An Orchestrator role** | The brief lists nine specialist agents and no one who decomposes the CEO's question, routes tasks, and assembles the answer. | §3.4 |
| **Prompt-injection / data-poisoning surface** | Agents read scraped web + social content; that content is adversarial input. Structured extraction with schemas, never instruction-following on fetched text. | §6 |

---

## 2. What already exists (build around it, not past it)

The platform does not start from zero. Verified, in production or in this repo:

| Asset | State |
|---|---|
| **Data lake** (`epocadatalake` Aurora): 169.3M Amazon ranking rows (daily, 2021→), 7.0M Walmart, 0.49M Five Below, 6.8M Amazon search terms (weekly), 6.3M social posts, 177.7M engagement rows | Live, collected daily |
| **Internal ground truth**: POS (`epocasql`), inventory/sell-through (`shaundatabase`), invoices/POs/HTS (`sqlmas90`), brands (`public`), `asinxref` ASIN↔item_code bridge (516 mappings) | Live, foreign tables |
| **Signal formulas F1–F16** with proven SQL for breakout radar, feature lift, cross-retailer gap, outcome ledger ([`../sql/`](../sql/)) | Validated on live data |
| **Call-out ledger** (34 call-outs) + F13 IQS scoring + weekly automated refresh + drift log + retrain trigger rule | Running via GitHub Actions |
| **Librarian** (internal docs/email knowledge base) and **Fable** research/analysis | Connected via MCP |
| Eight category decks + live dashboard rendering ledger data | Shipped |

Architectural implication: **the data lake is the foundation and the ledger is
the seed of the event-sourced spine.** Phase 1 productizes what exists (SQL
files → versioned services) rather than rebuilding it.

---

## 3. The architecture — five planes and a spine

```
                                ┌──────────────────────────────────────────────┐
                                │  P4 · EXPERIENCE                             │
                                │  Conversational UI · living dashboards ·     │
                                │  deck/report rendering · public API          │
                                └───────▲──────────────────────────▲───────────┘
                                        │ answers + artifacts      │ questions
┌──────────────────────────┐    ┌───────┴──────────────────────────┴───────────┐
│  THE LEDGER SPINE        │    │  P3 · AGENTS                                 │
│  (event-sourced)         │    │  Orchestrator · Trend Hunter · Social Intel  │
│                          │◀──▶│  Retail Intel · Product DNA · Explainer ·    │
│  every prediction,       │    │  Design · Sourcing&Eng · BI · Learning       │
│  decision, approval,     │    │  — stateless workers on Temporal queues —    │
│  outcome, retrain        │    └───────▲──────────────────────────▲───────────┘
│                          │            │ scores + evidence        │ tools (MCP)
│  + provenance triple:    │    ┌───────┴──────────────────────────┴───────────┐
│  (data snapshot,         │    │  P2 · SIGNAL & PREDICTION  (deterministic)   │
│   feature version,       │◀──▶│  Feature Factory F1–F9 → snapshots ·         │
│   model version)         │    │  PWS scoring · backtest harness ·            │
│                          │    │  calibration · model registry                │
│  = every prediction      │    └───────▲──────────────────────────────────────┘
│    reproducible          │            │ versioned features
└──────────▲───────────────┘    ┌───────┴──────────────────────────────────────┐
           │                    │  P1 · KNOWLEDGE                              │
           │ outcomes flow back │  Lakehouse (Aurora → +Iceberg/DuckDB) ·      │
           │ from sqlmas90 /    │  Concept Graph (entity resolution) ·         │
           │ shaundatabase /    │  Agent memory (pgvector) · Librarian RAG     │
           │ epocasql /         └───────▲──────────────────────────────────────┘
           │ Librarian                  │ normalized data
           │                    ┌───────┴──────────────────────────────────────┐
           └────────────────────│  P0 · ACQUISITION                            │
                                │  Ranking scrapers (Amz/WM/5B — running) ·    │
                                │  social collectors · search terms ·          │
                                │  new connectors (Costco, Target, TikTok      │
                                │  Shop, Reddit, Google Trends, Pinterest) ·   │
                                │  drift alarms · gap backfill                 │
                                └──────────────────────────────────────────────┘
```

### 3.1 P0 — Acquisition

The existing collectors already feed `crystalball` daily; they are the model
for every new connector. Rules for the plane:

- **Connectors are dumb and durable.** Fetch → validate against a schema →
  append raw to the lake with a collection timestamp. No interpretation at the
  edge; interpretation belongs to agents reading normalized data.
- **Every connector emits health telemetry** (rows/day, schema hash, latency),
  and a watchdog alarms on drift or silence — a dead scraper discovered three
  weeks late is three weeks of blind forecasting. Today's gap: nothing alarms
  if a collector silently stops.
- **New sources by expected signal value, not by brief's list order.** The
  brief names eleven sources. Sequencing by lead-time value and joinability:
  TikTok Shop (commerce-proximate social — the earliest monetizable signal),
  Google Trends (free, clean API, category-level), Costco/Target assortment
  (whitespace for our two most strategic buyers), then Reddit/Pinterest.
- **Legal/robustness posture is explicit per source**: API-first where one
  exists, licensed data vendors where terms require, scraping only where
  posture is assessed and rate-limited. One source, one decision record.

### 3.2 P1 — Knowledge

Three subsystems:

**Lakehouse.** Aurora Postgres is the system of record today and stays so.
Two evolutions, each on a trigger rather than on faith: (1) an **Apache
Iceberg** table layer on S3 for immutable daily snapshots of ranking data —
adopted when reproducible backtests need cheap time-travel beyond what
`cb_stamp` filtering gives us, or when analytical scans start hurting Aurora
(trigger: feature-factory runs > 15 min or interfering with collection); (2)
**DuckDB** as the analytical engine reading those snapshots — features over
169M rows are columnar-scan work, not OLTP work. The foreign-table schemas
(`sqlmas90`, `shaundatabase`, `epocasql`) get nightly extracted into the
lakehouse so outcome joins stop paying FDW latency.

**Concept Graph (the entity-resolution service).** The subsystem §1.3 argues
for. A `concept` node (e.g. *cast-aluminum ceramic cookware, detachable
handle*) links to: ASINs, Walmart/Five Below product IDs, search terms,
hashtags, Epoca item_codes, retailer assortment entries, and call-outs.
Resolution is **layered, cheapest first**: exact keys (`asinxref`, UPCs) →
deterministic rules (brand + normalized attributes) → embedding similarity
(pgvector over titles/descriptions) → LLM adjudication of ambiguous pairs →
**human curation as the final tier**, which is exactly the
`linked_item_codes` curation loop the flywheel doc already prescribes. Every
edge stores its provenance and confidence; downstream consumers can demand
"exact-match edges only" (ledger scoring) or accept fuzzy edges (exploratory
trend scans). The graph lives in Postgres (nodes/edges tables + pgvector) — a
dedicated graph database is unjustified at this cardinality.

**Agent memory.** Three scopes, all queryable, all versioned:
*domain memory* (retailer profiles, factory records, category playbooks —
structured rows owned by their domain agent), *episodic memory* (what was
asked, answered, decided — derived from the ledger spine), and *document
memory* (Librarian RAG: decks, emails, WGSN research, buyer meeting notes).
No agent hoards knowledge in prompts; if it learned something durable, it
writes it to memory where every other agent can read it.

### 3.3 P2 — Signal & Prediction (the deterministic core)

**Feature Factory.** F1–F9 graduate from SQL files to scheduled, versioned
transformations (dbt-style DAG or plain SQL+Python under CI — tooling is
secondary; versioning and tests are not). Each run emits **feature
snapshots**: per concept/product, per day — `(velocity, acceleration,
review_velocity, search_demand, social_lead, seasonal_fit, lifecycle_stage,
feature_lifts, …)` — written to the lakehouse keyed by
`(entity, date, feature_code_version)`. Snapshots are what make F10 retraining
honest (features *as of the call-out date*, no look-ahead) and what make any
historical prediction replayable.

**Prediction Service** (FastAPI). Endpoints, all read-only over snapshots:
- `score(concepts | category, retailer, window)` → PWS-ranked list, each row
  carrying score, subscores, confidence interval, evidence links, and the
  **provenance triple** (data snapshot ID, feature version, model version).
- `whitespace(retailer, category, window)` → F12 gap ranking.
- `forecast(concept, window)` → dated demand curve with error bands (F7/F15).
- `feasibility(concept, retailer_guardrail)` → F14 margin gate verdict.
- `explain(prediction_id)` → full factor decomposition for any past score.

**Backtest & calibration harness.** The credibility engine and the platform's
only defensible marketing claim. Freeze the model at `T−12mo`, replay,
publish precision@K vs the "pick current bestsellers" baseline — continuously,
on every model version, as a CI gate: **a model version that scores worse than
its predecessor on the held-out window cannot be promoted.** Confidence
scores are calibrated (isotonic/conformal on backtest residuals) so that
stated 70% ≈ realized 70%; the calibration curve itself is a published,
buyer-visible artifact.

**Model registry.** Every PWS weight-set: version, training data (which ledger
rows, which snapshots), fit metrics, approval record (retrains are
human-approved — §5), rollback pointer.

### 3.4 P3 — Agents

**The contract** — the whole reason new agents don't change the architecture:

```yaml
# every agent ships this manifest
agent: retail-intelligence
version: 1.4.0
owns: retailer domain knowledge          # exactly one domain
consumes: TaskSpec<RetailFitRequest>     # typed, schema-versioned input
produces: Artifact<RetailFitAssessment>  # typed, schema-versioned output
tools: [lake.sql_readonly, librarian.search, web.research]   # MCP, least-privilege
memory:
  reads: [concept_graph, retailer_profiles]
  writes: [retailer_profiles]            # only its own domain
evals: [retail_fit_golden_set >= 0.85, profile_freshness <= 30d]
escalation:
  - unknown_retailer -> human
  - confidence < 0.5 -> flag_low_confidence   # never silently guess
budget: {tokens_per_task: 200k, model_tier: reasoning}
```

Registering the manifest is the *entire* integration surface. The runtime
(Temporal) gives every agent the same lifecycle: pull typed task from queue →
execute with declared tools → emit typed artifact + trace + cost → ack.
Artifacts are immutable, stored with provenance, and are the only hand-off
medium between agents. Parallelism is free (queues fan out); retries, timeouts,
and human-approval pauses are workflow primitives, not agent code.

**The roster.** The brief's nine, sharpened — each with its one domain, and an
explicit note on what inside it is code vs. LLM:

| Agent | Owns | Deterministic core | LLM judgment |
|---|---|---|---|
| **Orchestrator** *(added)* | Question decomposition & answer assembly | Task-graph templates for known question shapes | Decomposing novel questions; drafting the executive answer |
| **Trend Hunter** | Anomaly triage across all acquisition sources | Breakout radar (F1/F2) runs on schedule | Deciding which anomalies are *concepts* worth tracking; naming them; seeding the concept graph |
| **Social Intelligence** | Social signal interpretation | F5 engagement math, creator-reach stats | Sentiment nuance, meme-vs-durable-trend judgment (with the F6/F8 agreement guardrail from Loop 2.0 §10) |
| **Retail Intelligence** | Retailer profiles: price architecture, merch strategy, assortment, shelf constraints, seasonal calendars | Assortment-coverage computation (F12 input) | Profiling from research + Librarian; buyer-fit reasoning |
| **Product DNA** | The concept graph | Layered entity resolution (§3.2) | Attribute extraction from titles/reviews/images; ambiguous-match adjudication; curation queue for humans |
| **Explainer** *(replaces "Prediction Engine agent")* | Narrative around scores | — (reads Prediction Service output only) | The causal "why", evidence-cited, in buyer language. Never alters a score. |
| **Design** | Visual & positioning artifacts | Template/brand-system constraints | Packaging concepts, renders, palettes, planogram concepts, copy — all watermarked drafts until human-approved |
| **Sourcing & Engineering** | Feasibility → specs | F14 margin model over `sqlmas90` history | Factory briefs, BOM/materials suggestions, spec drafting; CAD-ready concepts in later phases |
| **Business Intelligence** | Rendered deliverables | Chart generation from live queries | Deck/report/board-presentation assembly, retailer-tailored |
| **Learning** | The flywheel | Ledger refresh, drift detection, retrain trigger (already automated) | Funnel-attribution analysis (F16): *why* did call-outs die; retrain proposals with rationale for human approval |

Two roster notes. First, **Trend Hunter is not the scraper** — collectors are
P0 infrastructure; the agent is the analyst watching their output. Second, the
brief's "Prediction Engine" lives in P2 as a service; the **Explainer** agent
is deliberately quarantined from it so explanation can never contaminate
scoring.

### 3.5 P4 — Experience

The CEO question, end to end:

> *"What products should we launch at Costco for Spring 2028 under our
> housewares brand?"*

1. **Orchestrator** parses → `(retailer: Costco, window: Spring 2028, brand
   constraint: housewares, intent: opportunity ranking)`; fans out a task graph.
2. **Fast lane (seconds → ~2 min):** Prediction Service returns precomputed
   PWS + whitespace for Costco-fit categories filtered to the brand's price
   architecture; Retail Intelligence overlays Costco constraints (club pack
   sizes, price points, seasonal reset calendar); Sourcing gate drops
   candidates that can't hit margin; Explainer writes the why with evidence
   links; BI renders trend graphs from live series. The CEO has a ranked,
   evidenced answer with confidence scores — each row traceable to the exact
   snapshot and model version that produced it.
3. **Slow lane (minutes → hours, streamed):** Design produces packaging
   concepts and renders; Sourcing & Engineering drafts factory
   recommendations and a risk analysis; BI assembles the full deck. Each
   artifact lands in the answer thread as it clears its approval gate.
4. **The ask becomes a record.** Recommendations the team acts on are written
   to the ledger as call-outs — the question itself feeds the flywheel.

Surfaces: conversational UI (primary), the living dashboard (already
prototyped in this repo), rendered decks, and the same API customers will
eventually buy — internal use is the beta program for the Bloomberg-terminal
product.

### The Ledger Spine — event sourcing exactly where it pays

Event-source **decisions, not data**. Ranking/social rows are already
append-only time series in the lake; wrapping 350M rows in event envelopes
adds cost and no truth. The spine records the events whose history *is* the
business:

```
CalloutIssued · PitchDelivered · BuyerResponded · FeasibilityAssessed ·
PORaised · SellThroughObserved · ReorderObserved · PredictionScored ·
ModelRetrainProposed · ModelRetrainApproved · ApprovalGranted/Denied ·
AgentTaskCompleted (hash + cost + trace ref)
```

Append-only Postgres table, artifacts in object storage, projections
materialize the current-state views (the ledger CSV of today becomes a
projection). This gives traceability ("every decision traceable"),
reproducibility (provenance triple on every `PredictionScored`), and the
training-label stream for the Learning agent — one mechanism, three
requirements.

---

## 4. Technology decisions

Stack requested vs. committed, with reasons and revisit-triggers. The bias:
**adopt on trigger, not on brochure** — every premature platform component is
headcount spent not improving prediction accuracy.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Languages | **Python** (data/agents), **TypeScript** (UI) | Requested; correct; ecosystem | — |
| API layer | **FastAPI** | Requested; typed contracts via Pydantic align with agent manifests | — |
| System of record | **Postgres (Aurora)** — already live | The data lake exists here; migration is negative-value | — |
| Vector store | **pgvector** in the same Postgres | Concept-graph and memory embeddings are joins-with-SQL workloads; a separate vector DB adds an ops surface and a consistency problem for zero current benefit | >~50M embeddings or p95 similarity queries degrade |
| Analytics engine | **DuckDB** over lake snapshots | Feature factory is columnar scans over 169M+ rows; free, embeddable, fast | Multi-writer/concurrent-cluster needs → warehouse |
| Snapshot layer | **Apache Iceberg on S3** | Time-travel = reproducible backtests; cheap immutable history | Adopt at Phase-2 trigger (§3.2), not before |
| Workflow engine | **Temporal** | Durable execution, retries, human-in-loop pauses, fan-out — the agent runtime's hard parts, solved | — (adopt Phase 2) |
| Orchestration/infra | **Docker + a managed container service first**; K8s when service count / autoscaling demand it | K8s on day 1 is ops tax with no accuracy payoff | >10 services or bursty agent fleets |
| LLMs | **Claude (Fable/Opus-class) for reasoning & narrative; small/cheap models (Haiku-class) for high-volume extraction; open-source (embedding + attribute-extraction) where volume × cost dominates; OpenAI/Gemini via a router as fallback/eval-comparison** | Route by task value; never one model for everything; provider-agnostic router prevents lock-in | Quarterly cost/quality review |
| Tool bus | **MCP** for every tool an agent touches | One integration standard = least-privilege manifests are enforceable; already how Librarian/SQL are wired | — |
| RAG | **Librarian** as document memory + citations mandatory | Exists; the ground-truth trail for "explain why" | — |
| Source control / CI | **GitHub + Actions** | Already runs the flywheel cron | — |

---

## 5. Human approval loops — the autonomy ladder

Humans sit at the four points where an error is expensive or public, and
autonomy expands only as calibration is *proven*:

| Gate | Human decides | Relaxes when |
|---|---|---|
| **Call-out approval** | Which recommendations become official ledger call-outs (pitch = spent buyer credibility) | Never fully; threshold widens as hit rate rises |
| **External artifacts** | Any deck/render/brief leaving the building | Watermarked internal drafts flow freely from day 1 |
| **Model retrains** | Learning agent *proposes* weights + rationale; a human promotes | Auto-promote only if backtest-CI + drift checks pass *and* change < threshold |
| **Ledger curation** | `linked_item_codes` exact-match curation (the human half of the flywheel) | Shrinks as Product DNA's resolution precision is demonstrated per category |

Rule of thumb encoded in every agent manifest: **agents act freely on
reversible internal artifacts; anything irreversible or external is a workflow
pause.** The ladder is data-driven — each gate publishes its own
human-override rate, and a gate whose overrides drop near zero for two
quarters is a candidate for relaxation.

---

## 6. Cross-cutting: observability, evals, cost, safety

- **Tracing.** Every task carries a trace ID from question → agent calls →
  tool calls → artifacts; every artifact links back to its trace. "Every
  action is logged" comes free from the runtime, not from agent discipline.
- **Evals as CI.** Each agent's manifest declares golden-set evals; the
  Prediction Service has the backtest gate (§3.3). Agents and models that
  regress don't deploy. LLM-judge evals are seeded from human override
  decisions at the approval gates — the gates generate the eval data.
- **Cost governance.** Budgets per task (manifest), per question (Orchestrator
  enforces), per cycle (platform). Token spend is a first-class metric next to
  latency. Model routing (§4) is the main lever; caching evidence bundles per
  concept is the second.
- **Adversarial-input posture.** Scraped titles, reviews, and social posts are
  untrusted data — agents extract from them into schemas; they never treat
  fetched text as instructions. Review-bombing and fake-engagement patterns
  are anomaly-flagged in P0 before they reach signals (a competitor gaming our
  collectors is a real attack on prediction accuracy).
- **Versioning.** Data snapshots (Iceberg), feature code (git tag in snapshot
  key), models (registry), agents (manifest semver), prompts (versioned with
  agent). The provenance triple on every prediction composes them.

---

## 7. Phased roadmap

Each phase names its north-star impact (§0) and a hard exit criterion. Phases
overlap; exit criteria don't.

**Phase 0 — done (this repo).** Strategy, F1–F16, validated SQL, call-out
ledger + IQS + weekly automated refresh, decks, dashboard. *The flywheel
already turns by hand.*

**Phase 1 (months 0–3) — Productize the deterministic core.**
Feature Factory with versioned snapshots; Prediction Service API (score /
whitespace / forecast / explain / feasibility-v0); backtest harness with
published precision@K vs bestseller baseline; nightly extraction of foreign
schemas; connector health alarms; ledger moves from CSV to the event-sourced
spine (CSV becomes a projection).
*Outcomes moved: #1, #2. Exit: a published, reproducible backtest hit rate —
the number every future model must beat.*

**Phase 2 (months 3–6) — Agent runtime + knowledge agents.**
Temporal runtime + agent contract + registry; Orchestrator, Trend Hunter,
Product DNA (concept graph v1 with layered resolution + curation queue),
Retail Intelligence (profiles for the strategic nine retailers), Explainer.
Analyst-facing conversational surface answering scoped questions with
evidence. First new acquisition connectors (TikTok Shop, Google Trends).
*Outcomes moved: #1, #3. Exit: an analyst gets a ranked, evidenced,
confidence-scored category answer in < 5 minutes without touching SQL.*

**Phase 3 (months 6–9) — Generation lane + approval loops.**
Design, Sourcing & Engineering (F14 gate mandatory on every recommendation),
Business Intelligence agents; approval-gate workflows; deck generation that
replaces hand-built decks; Social Intelligence agent on the social pipeline.
*Outcomes moved: #3, #4. Exit: a retailer-ready deck produced end-to-end with
humans only at gates — cycle latency measured in hours, and every pick
margin-gated.*

**Phase 4 (months 9–12) — Close the loop at platform level.**
Learning agent runs drift → attribution → retrain-proposal automatically;
ledger enriched to hundreds of call-outs (historical backfill via Librarian +
Product DNA matching); calibrated confidence published; the full CEO question
runs fast-lane + slow-lane end to end.
*Outcomes moved: all four, compounding. Exit: one full quarterly cycle where
retrained weights beat prior weights on held-out outcomes, hands-off except
approvals.*

**Phase 5 (12+ months) — Scale out and productize.**
More retailers, more categories, more connectors; agent fleet grows within the
same contract (this is where "hundreds of agents" happens — as instances and
specializations, not new architecture); multi-tenant hardening; the API/UI
becomes the customer-facing Bloomberg-terminal product, sold on the one thing
competitors can't copy quickly: **a years-deep, outcome-graded prediction
ledger proving calibrated accuracy.**

---

## 8. Risks — ranked by expected damage

| # | Risk | Why it's real | Mitigation |
|---|---|---|---|
| 1 | **Label sparsity / overfit** (34 call-outs; IQS currently saturating at 1.0) | The flywheel retrains on tiny n; a confidently-wrong model is worse than none | Interpretable models only; backtest carries statistical load; re-tune F13 caps (already flagged); grow ledger aggressively (Phase 4); validation holdouts per Loop 2.0 §10 |
| 2 | **Entity-resolution debt** | Every cross-source claim rides on the concept graph; bad joins silently corrupt labels and whitespace | Layered resolution with confidence-tagged edges; exact-only mode for scoring; human curation tier; per-category precision audits |
| 3 | **Acquisition fragility & legality** | Scrapers break silently; ToS postures shift; the platform is blind without them | Health alarms (Phase 1); per-source legal posture; vendor redundancy for critical signals; API-first sourcing |
| 4 | **Outcome latency** | Sell-through/reorder labels arrive 2+ quarters after prediction — the flywheel's clock is slow | Proxy metrics validated against outcomes; partial-credit IQS stages (pitched/accepted arrive fast); backfill historical call-outs to pre-load labels |
| 5 | **Trust & calibration failure** | One confidently-wrong buyer pitch costs more credibility than ten good ones earn | Calibrated confidence as a CI gate; margin-feasibility gate; human call-out approval; evidence links on everything |
| 6 | **Scope seduction** | Renders and CAD demo well; accuracy pays. The org will be tempted to build the demo | §0 deciding rule enforced in roadmap reviews; generation lane sequenced after the deterministic core |
| 7 | **LLM cost & drift** | Hundreds of agents × frontier models = silent five-figure days; provider model updates shift behavior | Budgets in manifests; routing; pinned model versions with eval-gated upgrades |
| 8 | **Signal gaming** | As Crystal Ball moves real buying decisions, fake engagement/review patterns become attacks on it | Anomaly detection in P0; multi-source agreement requirements (F6 + F8 concordance rule) before high-stakes calls |
| 9 | **Org adoption** | A flywheel nobody feeds (no call-outs logged, no curation) starves | Make logging free: recommendations auto-draft ledger entries; curation queue is a 5-min/week UI task; publish the hit rate internally so the ledger's value is visible |

---

## 9. Summary of the recommended architecture in six sentences

Keep the judgment/math split absolute: agents reason, a versioned
deterministic service scores, and the two never blur. Make the agent contract
— typed tasks, typed artifacts, declared tools/memory/evals/budgets — the
platform's real interface, so scaling to hundreds of agents is registration,
not re-architecture. Treat the concept graph and the outcome ledger as the two
crown-jewel data assets; every phase must deepen both. Event-source decisions
on a ledger spine with a provenance triple, so every prediction is
reproducible and every decision traceable by construction. Put humans at four
gates and let the data argue them open. And hold every proposal — including
each item in this document — to the north star: does it find trends earlier,
predict sell-through better, shorten development, or win more retailers?

*Next step: Phase 1, starting with the Feature Factory and the backtest
harness — because the first number this platform must produce is not a demo,
but its own measured hit rate.*
