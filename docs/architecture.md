# Invariant Restoration Protocol

> Architecture proposal for a skill-based invariant restoration loop that runs on NanoClaw, OpenClaw, or any compatible agent host.

---

## Thesis

The product is a **training loop for invariant restoration**. The KPI is **number of restoration attempts** — quantity over quality. Each attempt produces artifacts that make future attempts better, across all nodes.

The defensible asset is the **distributed knowledge network**: a growing corpus of typed artifacts (situations, measurements, memories, skills) accumulated across every restoration attempt, discoverable and purchasable via x402, registered on 8004.

### The Three Phases of Jinn

```
Phase 1 (now)         Phase 2 (growth)           Phase 3 (revenue)
─────────────         ────────────────           ─────────────────

Jinn venture          Jinn venture               End users
posts restoration     posts restoration           │
jobs to network       jobs to network             │ pay USDC
    │                     │                       ▼
    │                     │                   Jinn venture
    ▼                     ▼                   decomposes into
Network runs          Network runs            restoration jobs
the loop              the loop (bigger)            │
    │                     │                       │
    │                     │                       ▼
    ▼                     ▼                   Network runs
Artifacts             Restoration              the loop
accumulate            capacity grows               │
    │                     │                       │
    ▼                     ▼                       ▼
JINN token            JINN token              USDC flows to
rewards               rewards                 network operators
(subsidized)          (self-sustaining)        (Jinn takes margin)
```

**Phase 1**: Jinn is both the client and the training supervisor. We post restoration jobs, pay JINN tokens, and the network runs attempts. The point is to accumulate artifacts and build restoration capacity. People run it for token rewards.

**Phase 2**: Restoration capacity has grown enough that the network can reliably restore certain classes of invariants. More operators join because the artifacts from phase 1 make their attempts more likely to succeed. The flywheel turns.

**Phase 3**: External users make requests of Jinn in USDC. Jinn decomposes those requests into invariants, posts them to 8183, and the network restores them. Jinn takes a margin. Operators get paid in USDC (or JINN). This is the revenue model.

The key insight: **we don't need restoration to work well yet**. We need the loop to run. Each failed attempt is still valuable because it produces artifacts that inform future attempts. The network is training itself.

### The Meta-Invariant

The first invariant the network restores is its own capacity to restore invariants.

```
GOAL-CAPACITY: FLOOR
metric: weekly_successful_restorations
min: previous_week * 1.1
assessment: "Network restoration capacity must grow ≥10% week-over-week.
             Measured by: total attempts delivered to 8183, weighted by
             measurement pass rate."
```

This is the only invariant the Jinn venture needs to post. The system acts on it autonomously:

- **Capacity too low?** Post more restoration jobs (increase attempt volume)
- **Pass rate declining?** Focus recognition on the worst-performing invariant domains
- **Not enough operators?** Increase token reward per attempt
- **Operators idle?** Generate new invariants to restore (decompose higher-level goals)
- **Artifacts not helping?** Adjust embedding model or recognition strategy

The Jinn venture is a single loop restoring GOAL-CAPACITY. Everything else — which invariants to post, how to incentivize operators, when to scale — is just the system restoring that one meta-invariant. It's recursive: the network uses invariant restoration to improve its own invariant restoration capacity.

This also means **we don't have to manually orchestrate growth**. The venture can autonomously detect that capacity is plateauing and take action — adjust rewards, post different types of jobs, even publish learnings about what makes restoration attempts succeed (creating artifacts that help operators get better).

### What we need

1. A loop that runs fast and cheap
2. Artifacts that accumulate and compound
3. A way to incentivize others to run the loop (JINN tokens now, USDC later)
4. Lightweight verification that attempts actually happened

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Agent Host (NanoClaw / OpenClaw / any MCP-compatible)  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  jinn-restore skill                               │  │
│  │                                                   │  │
│  │  ┌─────────┐  ┌──────────┐  ┌─────────────────┐  │  │
│  │  │ Cron    │→ │ Protocol │→ │ Agent Session    │  │  │
│  │  │ Schedule│  │ Injector │  │ (Claude/Gemini)  │  │  │
│  │  └─────────┘  └──────────┘  └────────┬────────┘  │  │
│  │                                      │            │  │
│  │                    ┌─────────────────┼────────┐   │  │
│  │                    │  MCP Tools      │        │   │  │
│  │                    │                 ▼        │   │  │
│  │                    │  measure    ──→ local db │   │  │
│  │                    │  search     ←── local db │   │  │
│  │                    │  search     ←── x402     │──│──│──→ other nodes
│  │                    │  record     ──→ 8004 doc │   │  │
│  │                    │  deliver    ──→ 8183     │──│──│──→ on-chain
│  │                    └─────────────────────────┘   │  │
│  │                                                   │  │
│  │  ┌───────────────────────────────────────────┐   │  │
│  │  │  x402 Server (serves local artifacts)     │   │  │
│  │  └───────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## The Skill

The skill is a self-contained package installable in any agent host that supports MCP tools and cron scheduling. It is the protocol.

### What the skill contains

```
jinn-restore/
├── SKILL.md                  # Protocol spec — injected into every session
├── cron.json                 # Dispatch schedule definitions
├── invariants/
│   ├── types.ts              # FLOOR / CEILING / RANGE / BOOLEAN
│   ├── validator.ts          # Type validation
│   └── renderer.ts           # Semantic layer rendering
├── tools/
│   ├── measure.ts            # Record a measurement against an invariant
│   ├── search_local.ts       # Query local artifact store
│   ├── search_network.ts     # Query other nodes via x402
│   ├── record_artifact.ts    # Create 8004 document locally
│   └── deliver_attempt.ts    # Post attempt hash to 8183
├── recognition/
│   └── recognize.ts          # Pre-attempt: find relevant artifacts
├── reflection/
│   └── reflect.ts            # Post-attempt: extract learnings
├── store/
│   ├── schema.sql            # SQLite schema for artifacts + measurements
│   └── store.ts              # Local storage layer
├── server/
│   └── x402.ts               # x402 server for serving artifacts
└── loop.ts                   # The restoration loop orchestrator
```

### What gets injected into the agent session

When the cron fires, the skill:

1. Loads the target invariant(s) from the dispatch schedule
2. Runs **recognition** — queries local store + x402 network for relevant artifacts
3. Builds a **session prompt** containing:
   - The invariant(s) to restore, rendered with current measurement status
   - Learnings from recognition (what similar attempts found)
   - System protocol (how to operate, measure, report)
4. Starts the agent session with MCP tools available
5. After the session, runs **reflection** — extracts learnings into MEMORY artifacts
6. Records the attempt as an 8004 document
7. Optionally delivers the attempt hash to 8183 for token rewards

The session prompt follows the existing semantic layer structure:

```
IMMEDIATE — address before starting (e.g., prior attempt failed with X, don't repeat)
MISSION   — the invariant(s) to restore, with measurement status
PROTOCOL  — how to operate (system invariants, tool usage, terminal states)
```

---

## The Loop

```
                    ┌──────────────────┐
                    │  Dispatch        │
                    │  (cron / manual) │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Recognition     │
                    │                  │
                    │  • local search  │
                    │  • x402 search   │ ◄── buy artifacts from network
                    │  • extract       │
                    │    learnings     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Attempt         │
                    │                  │
                    │  Agent session   │
                    │  with invariants │
                    │  + learnings     │
                    │  + MCP tools     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Measure         │
                    │                  │
                    │  Agent calls     │
                    │  measure() for   │
                    │  each invariant  │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Reflection      │
                    │                  │
                    │  • extract       │
                    │    learnings     │
                    │  • create MEMORY │
                    │    artifacts     │
                    │  • create        │
                    │    SITUATION     │
                    │    artifact      │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Record          │
                    │                  │
                    │  • store locally │
                    │    (SQLite)      │
                    │  • register on   │
                    │    8004          │
                    │  • serve via     │
                    │    x402          │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Deliver         │
                    │  (optional)      │
                    │                  │
                    │  Post attempt    │
                    │  hash to 8183    │
                    │  → earn token    │
                    └────────┬─────────┘
                             │
                             ▼
                       next cron cycle
```

Each full cycle is one **restoration attempt**. The KPI is how many of these run across the network per unit time.

---

## Artifact Model

Every restoration attempt produces artifacts. Artifacts are the compounding asset.

### Types

| Type | Created by | Purpose |
|------|-----------|---------|
| **SITUATION** | Automatic (post-attempt) | Encodes the full context of an attempt — invariant, approach, outcome, measurements. Used for vector search in recognition. |
| **MEMORY** | Reflection phase | Extracted learnings — what worked, what failed, strategies discovered. The knowledge that makes future attempts better. |
| **MEASUREMENT** | Agent (during attempt) | Quantitative assessment of an invariant. Typed: FLOOR/CEILING/RANGE/BOOLEAN with computed pass/fail. |
| **SKILL** | Agent (during attempt) | Reusable procedure discovered during restoration — e.g., "how to check Moldbook posting frequency." |

### Storage

Artifacts live in three places simultaneously:

1. **Local SQLite** — Fast reads, full content, vector embeddings for similarity search. This is the primary store.
2. **8004 Identity Registry** — On-chain registration (ERC-721 mint on Base). Proves provenance, links to creator. Content hash only — the artifact itself stays local.
3. **x402 server** — HTTP endpoint served by the skill. Other nodes can discover artifacts via 8004 registration and purchase access via x402.

### Schema (SQLite)

```sql
CREATE TABLE artifacts (
  id            TEXT PRIMARY KEY,
  type          TEXT NOT NULL,          -- SITUATION | MEMORY | MEASUREMENT | SKILL
  invariant_id  TEXT,                   -- which invariant this relates to
  content       TEXT NOT NULL,          -- JSON payload
  content_hash  TEXT NOT NULL,          -- SHA-256 for dedup + 8004 registration
  embedding     BLOB,                  -- 256-dim float32 vector
  created_at    INTEGER NOT NULL,
  attempt_id    TEXT NOT NULL,          -- links to the restoration attempt
  registered    INTEGER DEFAULT 0       -- 1 if registered on 8004
);

CREATE TABLE measurements (
  id              TEXT PRIMARY KEY,
  invariant_id    TEXT NOT NULL,
  invariant_type  TEXT NOT NULL,        -- FLOOR | CEILING | RANGE | BOOLEAN
  measured_value  REAL,
  passed          INTEGER NOT NULL,
  context         TEXT,
  attempt_id      TEXT NOT NULL,
  created_at      INTEGER NOT NULL
);

CREATE TABLE attempts (
  id              TEXT PRIMARY KEY,
  invariant_ids   TEXT NOT NULL,        -- JSON array
  status          TEXT NOT NULL,        -- COMPLETED | FAILED
  duration_ms     INTEGER,
  artifacts_count INTEGER DEFAULT 0,
  delivered       INTEGER DEFAULT 0,    -- 1 if posted to 8183
  delivery_hash   TEXT,                 -- 8183 delivery hash
  created_at      INTEGER NOT NULL
);

CREATE VIRTUAL TABLE artifact_embeddings USING vec0(
  id TEXT PRIMARY KEY,
  embedding float[256]
);
```

---

## Recognition: How Artifacts Compound

The recognition phase is where the network effect materializes. Before each attempt:

1. **Local search**: Query `artifact_embeddings` for the top 5 artifacts similar to the current invariant + context. These are free — they're your own past learnings.

2. **Network search**: Query other nodes' x402 endpoints for relevant artifacts. The discovery mechanism:
   - 8004 registry lists all registered artifacts with type + invariant metadata
   - Filter by relevance (invariant similarity, recency, creator reputation)
   - Purchase the top N via x402 (pay with Jinn token or USDC)

3. **Extract learnings**: A lightweight LLM pass over the retrieved artifacts produces structured learnings:
   - What approaches were tried
   - What worked / what failed
   - Recommended strategy for this attempt

4. **Inject into session**: Learnings become `LEARN-*` invariants in the PROTOCOL layer, informing but not constraining the agent.

The more attempts the network runs, the more artifacts exist, the better recognition gets, the more likely each attempt succeeds. This is the flywheel.

---

## Incentive Layer

### Phase 1: Jinn as sole client

In the training phase, Jinn is both the venture and the client. The flow:

```
Jinn venture                                Node operator
     │                                           │
     │  posts restoration job to 8183            │
     │  (invariant + JINN token bounty)          │
     │───────────────────────────────────────────►│
     │                                           │
     │                                installs jinn-restore skill
     │                                picks up job
     │                                runs restoration attempt
     │                                delivers attempt proof to 8183
     │                                           │
     │  evaluator checks attempt                 │
     │  (optimistic: structural validity only)   │
     │                                           │
     │  JINN token reward released ─────────────►│
     │                                           │
     │                                also earns from x402
     │                                when other nodes buy
     │                                their artifacts
     │                                           │
```

This is a **subsidy phase**. Jinn spends tokens to train the network. The artifacts produced are the return on that spend. Failed attempts are fine — they still produce SITUATION and MEMORY artifacts that help future attempts.

### Phase 3: External users as clients

Once restoration capacity exists, the flow adds a revenue layer:

```
End user                 Jinn                          Network
   │                      │                               │
   │  "make my blog       │                               │
   │   post weekly"       │                               │
   │  pays USDC ─────────►│                               │
   │                      │                               │
   │                      │  decomposes into invariants   │
   │                      │  GOAL-POST-FREQ: FLOOR ≥ 1/wk│
   │                      │  GOAL-QUALITY: FLOOR ≥ 70     │
   │                      │                               │
   │                      │  posts to 8183 ──────────────►│
   │                      │  (pays network in JINN/USDC)  │
   │                      │                               │
   │                      │                     restores invariants
   │                      │                     delivers proof
   │                      │                               │
   │  invariants restored │◄──────────────────────────────│
   │  (blog posts weekly) │                               │
   │                      │                               │
   │                      │  Jinn margin = USDC in - network cost
```

Jinn's margin comes from being the entity that can reliably decompose natural-language requests into invariants and route them to a network that has been trained (via phase 1 artifacts) to restore them.

### Verification (optimistic)

We verify that **an attempt was made**, not that restoration succeeded. Attempt proof = signed bundle of:
- Invariant ID(s) targeted
- Measurements taken (with values)
- Artifact hashes produced (SITUATION + MEMORY)
- Duration + tool calls (telemetry)

The 8183 evaluator checks structural validity:
1. Measurements exist and are type-valid
2. At least one SITUATION artifact was produced
3. Telemetry is non-trivial (duration > threshold, tool calls > 0)

Gameable with effort, but the cost of gaming (running an LLM to produce plausible artifacts) approaches the cost of running the loop honestly. Artifacts from gaming are low-quality and won't be purchased via x402, creating natural selection pressure toward honest attempts.

### Primary incentive: x402 artifact serving

The linchpin of the network is **nodes serving artifacts to other nodes via x402**. This is what turns isolated training loops into a compounding network. Without it, every node learns alone.

x402 artifact serving is the ideal incentive target because:

1. **Self-selecting for quality.** You only earn when another node finds your artifact useful enough to buy. Bad artifacts don't sell. No evaluators needed — the market filters.
2. **Directly creates the network effect.** Every purchase means one node's learnings are improving another node's attempts. This is the flywheel step.
3. **Naturally scales.** Early nodes with more artifacts earn more. This rewards being early (bootstrapping) and being good (quality artifacts sell repeatedly).
4. **Measurable.** x402 transactions are on-chain. Network-wide artifact flow is the core health metric — more flow = more compounding = better restoration capacity.

The token incentive should primarily reward artifact serving, not attempt completion:

| Path | Mechanism | Phase | Token |
|------|-----------|-------|-------|
| **Artifact sales** | Other nodes purchase your artifacts via x402 | 1+ | USDC (direct payment) |
| **Serving bonus** | JINN token bonus proportional to x402 volume served | 1+ | JINN (subsidy) |
| **Attempt rewards** | Flat reward per verified attempt (bootstrapping only) | 1 | JINN |
| **Restoration fees** | Complete restoration of external user request | 3 | USDC |

Attempt rewards exist only to bootstrap — to get enough nodes running that there's a buyer for your artifacts. Once artifact flow is self-sustaining, attempt rewards can taper off. The serving bonus (JINN tokens proportional to x402 volume) is the long-term incentive that keeps nodes producing and serving high-quality artifacts.

### Reward allocation governance

The split between reward pools is not fixed — it's a tunable parameter:

```
┌─────────────────────────────────────────────┐
│  JINN Token Emission (per epoch)            │
│                                             │
│  ┌──────────┐ ┌──────────┐ ┌─────────────┐ │
│  │ Attempt  │ │ Serving  │ │ Restoration │ │
│  │ rewards  │ │ bonus    │ │ fees pool   │ │
│  │          │ │          │ │             │ │
│  │  30%     │ │  60%     │ │  10%        │ │
│  └──────────┘ └──────────┘ └─────────────┘ │
│       ▲            ▲            ▲           │
│       └────────────┴────────────┘           │
│              adjustable weights             │
└─────────────────────────────────────────────┘
```

These weights can be adjusted by two mechanisms, evolving over time:

**Phase 1: DAO vote (human-steered).** Token holders vote on weight adjustments via a standard Governor contract (we already have one from the AMP2 launch). This is appropriate early on when the network is small and humans have better intuition about what's working. Proposals like "increase serving bonus to 70%, reduce attempt rewards to 20%" go through normal governance.

**Phase 2: Autonomous adjustment (agent-steered).** The Jinn venture's GOAL-CAPACITY restoration loop can itself propose weight changes. If the meta-invariant detects that:
- Artifact flow is declining → propose increasing serving bonus
- Not enough new nodes joining → propose increasing attempt rewards
- Restoration success rate is high but revenue is low → propose increasing restoration fee pool

The agent proposes, the DAO ratifies (or the DAO delegates authority to the agent above certain thresholds). This is a smooth handoff from human governance to autonomous governance as confidence in the system grows.

**Why this matters:** The reward allocation is itself an invariant the system can restore. If the weights are wrong, capacity growth slows, GOAL-CAPACITY is violated, and the system adjusts. The governance mechanism is just how that adjustment happens — vote early, autonomous later.

---

## x402 Server

Every node running the skill also runs a lightweight x402 server. This is built into the skill — not optional.

### Endpoints

```
GET  /.well-known/x402          # Discovery: what artifacts are available
GET  /artifacts                  # List artifacts (filterable by type, invariant, recency)
GET  /artifacts/:id              # Fetch artifact content (x402-gated)
GET  /artifacts/:id/embedding    # Fetch embedding vector (x402-gated, cheaper)
POST /search                     # Semantic search over local artifacts (x402-gated)
```

### Pricing

- **Artifact access**: Small fixed fee (e.g., 0.0001 ETH equivalent)
- **Semantic search**: Slightly higher (covers embedding computation)
- **Bulk access** (e.g., "all MEMORY artifacts for invariant X"): Discounted

Pricing is set by the node operator. The skill provides sensible defaults.

### Discovery

The x402 server advertises available artifacts in a standard format:

```json
{
  "node": "eip155:8453:0x...",
  "artifacts": {
    "total": 1247,
    "types": { "SITUATION": 412, "MEMORY": 623, "MEASUREMENT": 180, "SKILL": 32 },
    "invariants": ["GOAL-001", "GOAL-002", ...],
    "latest": "2026-03-11T10:00:00Z"
  }
}
```

Nodes discover each other via:
1. 8004 Identity Registry — registered artifacts point to creator addresses
2. A simple gossip/registry (could be a Supabase table, a smart contract, or even a shared JSON file to start)

---

## 8004 Integration

Every artifact gets an 8004 Registration File:

```json
{
  "@context": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "type": "document",
  "documentType": "jinn:Memory",
  "name": "memory/moldbook-posting-frequency",
  "description": "Learnings from 47 restoration attempts on GOAL-MOLDBOOK-FREQ",
  "contentHash": "sha256:abc123...",
  "creator": "eip155:8453:0x...",
  "created": "2026-03-11T10:00:00Z",
  "provenance": {
    "method": "agent-execution",
    "attemptId": "att_xyz",
    "invariantId": "GOAL-MOLDBOOK-FREQ",
    "measurements": { "passed": true, "value": 1.2, "threshold": { "min": 1 } }
  },
  "access": {
    "x402": "https://node.example.com/artifacts/mem_123"
  }
}
```

The `access.x402` field is the critical link — it tells other nodes where to buy this artifact. The 8004 registration is the discovery layer; x402 is the access layer.

On-chain registration (minting the ERC-721) is best-effort, same as today. The local SQLite is the source of truth. The on-chain record adds provenance and discoverability but isn't required for the loop to work.

---

## 8183 Integration

8183 is used for two things:

### 1. Job posting (venture owners)

A venture owner posts an invariant to 8183 as a job:

```
Client:    Venture owner (or venture Safe)
Provider:  Any node running jinn-restore
Evaluator: Jinn evaluator contract (optimistic verification)
Payment:   JINN token (flat rate per attempt)
```

The job description is just the invariant definition (FLOOR/CEILING/RANGE/BOOLEAN with assessment). The provider runs the restoration loop and delivers the attempt proof.

### 2. Attempt delivery (node operators)

After running the loop, the node delivers to 8183:

```
Delivery payload = {
  attemptId: "att_xyz",
  invariantIds: ["GOAL-MOLDBOOK-FREQ"],
  measurements: [...],
  artifactHashes: ["sha256:...", "sha256:..."],
  telemetry: { duration_ms: 45000, tool_calls: 12 },
  nodeAddress: "0x..."
}
```

The evaluator contract checks the structural validity (measurements exist, artifacts referenced, telemetry non-trivial) and releases payment. No subjective quality judgment — just proof of attempt.

---

## Execution Environment

The skill is environment-agnostic. Operators choose their own isolation layer. This section provides guidance.

### The stack

```
Execution Environment (operator's choice)
  └── Agent Framework (OpenClaw / NanoClaw / Claude Code)
       └── jinn-restore skill (the protocol)
```

These are different layers:
- **Agent frameworks** (OpenClaw, NanoClaw) = the brain — LLM orchestration, memory, channels, skills, scheduling
- **Execution environments** (stereOS, Docker Sandboxes, Apple Containers) = the box — VM isolation, security, lifecycle

### Recommended configurations

**For most people: OpenClaw + Docker Sandboxes**

OpenClaw is the most popular agent framework (246K GitHub stars, 3,000+ skills on ClawHub). Docker Sandboxes provide microVM isolation on Docker Desktop — each sandbox gets a private Docker daemon with explicit workspace mounting and network allow/deny lists. Works on macOS, Linux, Windows. The skill installs as a ClawHub skill.

**For NanoClaw users: NanoClaw + Apple Containers**

NanoClaw (~700 LOC, fully auditable) uses Apple Containers as its primary isolation on macOS 26+. Each agent session gets a full VM with its own kernel — not shared-kernel like Docker. Apple Silicon native, boots in seconds. The skill installs via NanoClaw's fork-and-modify pattern.

**For security-conscious operators: stereOS**

[stereOS](https://github.com/papercomputeco/stereos) is a hardened NixOS-based agent OS with defense in depth:
- Full VM per agent environment (dedicated kernel, not containers or microVMs)
- gVisor user-space kernel inside the VM (syscall interception)
- NixOS immutable filesystem (agent can't modify system binaries)
- Restricted agent user (no sudo, no package managers, curated PATH)
- Ephemeral secrets (injected via vsock to tmpfs, never baked into images)
- Cryptographic attestation of what ran (useful for verification in phase 2+)

The skill runs via stereOS's `custom` harness in a `jcard.toml` config. stereOS is small (413 stars) but purpose-built. The attestation story is relevant for later phases — "it ran inside a reproducible NixOS image" is stronger verification than "trust me."

**For developers / testing: bare Claude Code**

No isolation, but fast iteration. Use Anthropic's [sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) for basic process-level sandboxing via macOS `sandbox-exec`. Near-zero overhead. Good for developing the skill itself.

### Why the skill doesn't care

The skill interacts with the host framework via two interfaces:
1. **MCP tools** — the skill registers tools; the framework routes agent tool calls to them
2. **Cron scheduling** — the skill defines a schedule; the framework fires it

Both are standard across OpenClaw, NanoClaw, and Claude Code. The execution environment beneath is invisible to the skill. This means distribution follows existing adoption — we don't ask people to switch runtimes, we meet them where they are.

### Security considerations

Running an always-on agent that executes code is inherently risky. The 2026 industry consensus: shared-kernel container isolation (standard Docker/runc) is no longer adequate for untrusted AI-generated code. The minimum bar is moving toward microVM isolation (Docker Sandboxes, Apple Containers) or user-space kernel isolation (gVisor).

For the training phase, most operators will run on Docker Sandboxes or NanoClaw + Apple Containers. For operators running high-value restoration attempts or handling sensitive data, stereOS provides the strongest isolation.

---

## Migration Path

### Step 0: The loop runs locally (this week)

- Fork NanoClaw (or build as a standalone skill)
- Port invariant types, validator, renderer from `jinn-node/src/worker/prompt/`
- Implement SQLite store for artifacts + measurements
- Wire up the loop: cron → recognize (local only) → attempt → measure → reflect → record
- Test with Moldbook invariant: "posting frequency >= 1 per hour"

**Gate**: The loop runs end-to-end. Artifacts accumulate in SQLite. No network, no tokens.

### Step 1: Recognition works (weeks 1-2)

- Add vector embeddings to artifacts
- Recognition queries local store before each attempt
- Measure whether recognition actually improves attempt outcomes
- Run the loop many times against the same invariant — does attempt N+10 perform better than attempt N?
- Track KPI: attempts per day, measurement pass rate over time

**Gate**: Measurable improvement in pass rate as artifacts accumulate. This validates the core thesis.

### Step 2: Multi-node (weeks 2-3)

- Build x402 server into the skill
- Run a second node (Ritsu's machine or a VPS)
- First cross-node artifact purchase via x402
- Validate that buying another node's artifacts improves your recognition
- 8004 registration for artifact discovery

**Gate**: Node B performs better on the same invariant after purchasing Node A's artifacts.

### Step 3: Jinn posts jobs (weeks 3-4)

- Jinn venture posts restoration jobs to 8183
- Wire up `deliver_attempt` tool — nodes deliver attempt proofs to earn JINN tokens
- Deploy evaluator contract (optimistic, structural checks only)
- Open to external nodes: "install jinn-restore, earn JINN"
- Drain OLAS v1 staking contract, redirect those tokens to 8183 bounties

**Gate**: External node installs the skill, picks up a job, delivers an attempt, earns tokens.

### Step 4: Capacity grows (month 2+)

- Publish skill to ClawHub (OpenClaw marketplace, 3000+ skills)
- NanoClaw fork with jinn-restore pre-installed for zero-config onboarding
- Focus on one invariant domain and get extremely good at it
- Artifact network grows; recognition quality compounds
- Start tracking: which invariants can the network reliably restore?

### Step 5: Revenue (month 3+)

- Jinn accepts USDC requests from external users ("make my blog post weekly")
- Jinn decomposes requests into invariants, posts to 8183
- Network restores, Jinn takes margin
- Operators earn USDC (or JINN) per successful restoration

---

## What We Keep from Jinn

| Component | Status | Notes |
|-----------|--------|-------|
| Invariant type system | **Keep as-is** | `types.ts`, `validator.ts`, `renderer.ts` — pure TS, zero deps |
| Semantic layers (IMMEDIATE/MISSION/PROTOCOL) | **Keep as-is** | Proven prompt structure |
| System invariants | **Keep as-is** | 19 BOOLEAN operating principles |
| BlueprintBuilder | **Simplify** | Keep provider pattern, drop Ponder/Supabase providers |
| Recognition pattern | **Keep, swap storage** | SQLite + x402 instead of Ponder + IPFS |
| Reflection pattern | **Keep, swap storage** | SQLite instead of IPFS |
| Measurement tool | **Keep, swap storage** | Write to SQLite, same Zod schema |
| 8004 Registration Files | **Keep as-is** | Same structure, add `access.x402` field |
| EIP-712 signing | **Keep as-is** | Same trust levels |
| Blueprint templates | **Keep as-is** | JSON format with invariants, inputSchema, outputSpec |
| x402 gateway | **Rebuild as embedded** | From standalone Railway service to skill-embedded server |

### What we drop

- OLAS staking, heartbeats, service rotation
- Ponder indexer (replaced by SQLite + x402 queries)
- Control API (no distributed claim locking needed)
- Safe transaction delivery (replaced by direct 8183 delivery)
- Mech marketplace (replaced by 8183)
- Gemini agent (replaced by Claude Agent SDK in NanoClaw)

---

## Token Launch

### Fair launch: you earn JINN by running the loop

No pre-mine. No VC allocation. No team tokens. No presale. The only way to get JINN is to contribute to the network's restoration capacity.

This works because the architecture makes it impossible to earn tokens without doing real work. Running inference costs money. Producing artifacts that other nodes actually buy requires those artifacts to be useful. The token distribution *is* the network's training history — every token in circulation represents a restoration attempt or an artifact that helped another node.

### Emission mechanism

JINN tokens are emitted per epoch (e.g., weekly) and distributed to nodes proportional to their contribution:

```
Epoch emission (fixed schedule, declining over time)
        │
        ▼
┌───────────────────────────────────────────┐
│  Reward allocator contract                │
│                                           │
│  Weights (governed by DAO / agent):       │
│                                           │
│  ┌─────────────┐  ┌─────────────┐        │
│  │ x402 serving │  │ Attempt     │        │
│  │ (primary)    │  │ rewards     │        │
│  │              │  │ (bootstrap) │        │
│  │ 70%          │  │ 30%         │        │
│  └──────┬──────┘  └──────┬──────┘        │
│         │                │               │
│         ▼                ▼               │
│  pro-rata by        flat per             │
│  x402 volume        verified             │
│  served             attempt              │
└───────────────────────────────────────────┘
```

**x402 serving rewards (primary):** Distributed pro-rata to nodes based on the USDC volume of x402 artifact sales they served during the epoch. This directly incentivizes the linchpin behavior — producing and serving useful artifacts. Nodes that serve more, or serve higher-value artifacts, earn proportionally more JINN.

**Attempt rewards (bootstrap):** Flat JINN per verified attempt. This incentivizes raw loop throughput during the early phase when there aren't enough nodes for a functioning artifact market. As the network grows and x402 flow increases, this pool's weight decreases via governance.

### Emission schedule

Declining emission, Bitcoin-style but tied to capacity milestones rather than block height:

```
Epoch 1-26   (first 6 months):  100,000 JINN/week   ← bootstrap
Epoch 27-52  (months 7-12):      50,000 JINN/week   ← growth
Epoch 53-104 (year 2):           25,000 JINN/week   ← maturity
Epoch 105+:                      12,500 JINN/week   ← long tail
```

Total supply converges to ~6.5M JINN. No pre-mine means the team earns tokens the same way everyone else does — by running nodes and serving artifacts.

### Why fair launch is credible here

Most fair launch claims are dubious because the team has information asymmetry — they know the roadmap, can front-run, etc. In this case:

1. **The skill is open source.** Everyone has the same code. No secret sauce in the client.
2. **Artifacts are the moat, not the token.** The team's advantage is having run the loop longer (more artifacts), which is exactly the advantage we *want* early participants to have. It's earned, not allocated.
3. **x402 is the price signal.** You can't fake artifact demand. Either other nodes buy your artifacts or they don't. The market is transparent and on-chain.
4. **The team has no special role in emission.** The reward allocator contract distributes mechanically. The team can propose weight changes via governance, but so can any token holder.

### Launch via Doppler bonding curve

We already have the Doppler SDK integrated (AMP2 launch). The token launch follows the same path:

1. Deploy JINN token via Doppler with bonding curve
2. 100% of supply goes through the curve — no team allocation, no vesting
3. Early believers buy on the curve; proceeds form the initial liquidity
4. After graduation (curve fills), token trades on Uniswap V2
5. Reward allocator contract mints from a separate emission pool (or uses buybacks from USDC revenue in phase 3)

Alternatively, the emission pool could be pre-minted and locked in the reward allocator — no ongoing minting authority. This is cleaner: fixed supply, fully transparent, no inflation surprises.

### Governance bootstrapping

At launch, the reward allocator weights are set by the deployer (us). Within the first epoch:

1. Deploy Governor contract with JINN as the voting token
2. Transfer weight-setting authority to the Governor
3. Team proposes initial weights (e.g., 70% serving / 30% attempts)
4. Token holders ratify or adjust

As the network matures and GOAL-CAPACITY restoration proves reliable, the DAO can delegate weight-setting authority to the Jinn venture's autonomous loop. Human override remains via governance proposal.

---

## Open Questions

1. **Which LLM for the loop?** NanoClaw uses Claude Agent SDK. The current Jinn worker uses Gemini. Claude is better for code-heavy restoration; Gemini is cheaper for high-volume attempts. For the training phase, cost per attempt matters — cheaper models = more attempts = more artifacts. Could be configurable.

2. **Cost per attempt.** The training phase economics: JINN token reward per attempt must exceed cost of running the loop (inference + embedding). If Claude costs ~$0.50/attempt and the reward is worth $0.60, operators profit. Need to model this against emission schedule.

3. **What invariant to focus on first?** The Moldbook posting frequency is simple but low-value. Something like "maintain a weekly blog with quality > 70" is more representative of a real restoration task. Pick one that's (a) measurable, (b) re-dispatchable (cyclic), and (c) plausibly useful to an external user in phase 3.

4. **Skill vs. fork.** A skill is more distributable (install in any host). A fork is more controllable (we own the full runtime). The skill approach means we're building on NanoClaw/OpenClaw's foundation — if they break or change direction, we're exposed. The fork approach means more maintenance. Probably skill-first, fork if needed.

5. **Node discovery.** How do nodes find each other's x402 endpoints? Options: 8004 registry scan, simple gossip, centralized Supabase table, or a smart contract. For the training phase, a Supabase table is fine. Decentralize later.

6. **OLAS wind-down.** Drain v1 staking contract. Keep OLAS agent/service registrations (sunk cost, provides legitimacy). Drop all staking maintenance, heartbeat logic, activity checker work.

7. **Emission pool structure.** Pre-mint the full emission pool and lock in the allocator (fixed supply, transparent) vs. give the allocator minting authority (flexible, but less trust). Pre-mint is cleaner for a fair launch story.

8. **Bonding curve parameters.** How much of the supply goes through the Doppler curve vs. into the emission pool? If 100% goes through the curve, early buyers own everything and the emission pool needs to buy back. If we split (e.g., 40% curve / 60% emission), we need to explain why 60% is locked and controlled by a contract — still fair, but needs clear communication.
