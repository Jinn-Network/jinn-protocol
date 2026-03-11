# Step 0: The Loop Runs Locally

> Design doc for the first implementation of the invariant restoration loop.

---

## Premise

The agent host (OpenClaw, Claude Code, Gemini CLI, Codex CLI — whatever) handles the runtime: cron, sessions, tools, filesystem. We don't build any of that.

We build **a skill**. The skill is the protocol. It follows the [AgentSkills spec](https://agentskills.io/specification) so it works across all 26+ adopting platforms. No MCP server, no npm package, no running process. Just files.

---

## What we ship

A single skill directory, publishable to ClawHub:

```
jinn-restore/
├── SKILL.md                          # The protocol (AgentSkills format)
├── references/
│   ├── invariant-types.md            # FLOOR / CEILING / RANGE / BOOLEAN reference
│   └── file-conventions.md           # How to read/write the data directory
├── scripts/
│   ├── measure.sh                    # Helper: validate + write a measurement
│   ├── search.sh                     # Helper: search artifacts by keyword
│   └── init.sh                       # Helper: set up the data directory
└── blueprints/
    └── moldbook-posting.json         # Example blueprint
```

### Data directory (created at runtime)

The agent reads and writes plain JSON files. No database, no server.

```
~/.jinn-restore/                      # or wherever the user configures
├── blueprints/
│   └── moldbook-posting.json
├── artifacts/
│   ├── mem_2026-03-11T10-00_moldbook-rate-limit.json
│   ├── mem_2026-03-11T11-00_batch-endpoint-works.json
│   ├── sit_2026-03-11T10-00_attempt-001.json
│   └── sit_2026-03-11T11-00_attempt-002.json
├── measurements/
│   ├── GOAL-MOLDBOOK-FREQ/
│   │   ├── 2026-03-11T10-00.json
│   │   └── 2026-03-11T11-00.json
│   └── latest.json                   # Latest measurement per invariant
└── attempts/
    ├── 2026-03-11T10-00.json
    └── 2026-03-11T11-00.json
```

Every file is self-contained JSON. The agent uses `Read`, `Write`, `Glob`, `Bash` — tools it already has in any host.

---

## SKILL.md

```yaml
---
name: jinn-restore
description: >
  Invariant restoration protocol. Use when a cron job fires with a blueprint
  path, or when asked to restore invariants. Reads a blueprint JSON defining
  FLOOR/CEILING/RANGE/BOOLEAN invariants, searches past artifacts for learnings,
  measures current state, takes actions to restore violated invariants, and
  records what it learned for future attempts.
license: MIT
compatibility: Requires curl or equivalent HTTP tool for web-based invariants.
metadata:
  author: jinn-network
  version: "0.1.0"
---

# Jinn Restoration Protocol

You are running a restoration attempt. Your job is to restore the invariants
defined in a blueprint to their target state.

## Setup

The data directory is at the path specified in the cron prompt, or defaults
to `~/.jinn-restore/`. If it doesn't exist, create it:

```
mkdir -p ~/.jinn-restore/{artifacts,measurements,attempts,blueprints}
```

## Workflow

### 1. Read the blueprint

Load the blueprint JSON. It defines invariants:

```json
{
  "id": "GOAL-MOLDBOOK-FREQ",
  "type": "FLOOR",
  "metric": "posts_in_last_hour",
  "min": 1,
  "assessment": "How to check and restore this invariant"
}
```

Types: see `references/invariant-types.md`.

### 2. Search for past learnings

Glob `~/.jinn-restore/artifacts/mem_*.json` and read recent MEMORY artifacts.
Look for entries whose `invariant_id` matches your blueprint's invariants,
or whose `tags` are relevant. Read the `content` field for learnings.

Also glob `~/.jinn-restore/artifacts/sit_*.json` for SITUATION artifacts
from past attempts — these describe what was tried and what happened.

Prioritize recent artifacts (filename contains timestamp).

### 3. Measure before acting

For each invariant, assess its current state. Write a measurement file:

```
~/.jinn-restore/measurements/{invariant_id}/{timestamp}.json
```

```json
{
  "invariant_id": "GOAL-MOLDBOOK-FREQ",
  "invariant_type": "FLOOR",
  "measured_value": 0,
  "min_threshold": 1,
  "passed": false,
  "context": "Checked Moldbook API — 0 posts in last hour",
  "timestamp": "2026-03-11T10:00:00Z"
}
```

Also update `~/.jinn-restore/measurements/latest.json` — a map of
invariant_id to latest measurement:

```json
{
  "GOAL-MOLDBOOK-FREQ": {
    "passed": false,
    "measured_value": 0,
    "timestamp": "2026-03-11T10:00:00Z"
  }
}
```

If all invariants pass, report COMPLETED and stop.

### 4. Restore

Take whatever actions are needed to bring violated invariants back into
bounds. Use any available tools (Bash, curl, WebFetch, file editing, etc.).

The blueprint's `assessment` field tells you how to evaluate and restore
each invariant.

### 5. Measure after acting

Re-measure each invariant you attempted to restore. Write new measurement
files.

### 6. Record learnings

Write MEMORY artifacts for anything you learned:

```
~/.jinn-restore/artifacts/mem_{timestamp}_{slug}.json
```

```json
{
  "type": "MEMORY",
  "invariant_id": "GOAL-MOLDBOOK-FREQ",
  "name": "moldbook-rate-limit-workaround",
  "content": "The Moldbook API rate-limits after 10 requests per minute. Use the batch endpoint at /api/v2/posts/batch instead of individual POST requests. This was discovered when the direct approach failed with HTTP 429.",
  "tags": ["moldbook", "rate-limit", "api"],
  "timestamp": "2026-03-11T10:15:00Z"
}
```

Be specific. Future attempts will read these files. Write what worked,
what failed, and what to try differently.

### 7. Record the attempt

Write a SITUATION artifact summarizing this attempt:

```
~/.jinn-restore/artifacts/sit_{timestamp}_attempt.json
```

```json
{
  "type": "SITUATION",
  "invariant_ids": ["GOAL-MOLDBOOK-FREQ"],
  "status": "RESTORED",
  "summary": "Moldbook posting frequency was 0/hour. Published one post via batch API. Frequency now 1/hour.",
  "measurements_before": { "GOAL-MOLDBOOK-FREQ": { "passed": false, "value": 0 } },
  "measurements_after": { "GOAL-MOLDBOOK-FREQ": { "passed": true, "value": 1 } },
  "learnings_used": ["mem_2026-03-11T10-00_moldbook-rate-limit.json"],
  "timestamp": "2026-03-11T11:00:00Z"
}
```

Also write an attempt record:

```
~/.jinn-restore/attempts/{timestamp}.json
```

```json
{
  "id": "att_2026-03-11T11-00",
  "blueprint": "moldbook-posting",
  "invariant_ids": ["GOAL-MOLDBOOK-FREQ"],
  "status": "RESTORED",
  "artifacts_created": [
    "mem_2026-03-11T11-00_batch-endpoint-works.json",
    "sit_2026-03-11T11-00_attempt.json"
  ],
  "timestamp": "2026-03-11T11:00:00Z"
}
```

### 8. Stop

One attempt = one session. The host handles re-dispatch.

## Terminal states

End your response with exactly one of:
- **COMPLETED** — All invariants already in bounds, no action needed
- **RESTORED** — Invariants were violated, actions taken, now in bounds
- **FAILED** — Could not restore; explain why
- **PARTIAL** — Some invariants restored, others still violated

## Invariant types (quick reference)

- **FLOOR**: `measured_value` must be `>= min`
- **CEILING**: `measured_value` must be `<= max`
- **RANGE**: `measured_value` must be `>= min` AND `<= max`
- **BOOLEAN**: `passed` must be `true`
```

---

## Blueprint format

```json
{
  "name": "moldbook-posting",
  "description": "Maintain posting frequency on Moldbook",
  "invariants": [
    {
      "id": "GOAL-MOLDBOOK-FREQ",
      "type": "FLOOR",
      "metric": "posts_in_last_hour",
      "min": 1,
      "assessment": "Check Moldbook for posts by this account in the last hour. If below threshold, draft and publish a new post that aligns with the account's voice and recent topics.",
      "examples": {
        "do": [
          "Check posting history before creating new content",
          "Match the tone and topics of recent posts"
        ],
        "dont": [
          "Post duplicate content",
          "Post without checking current frequency first"
        ]
      }
    }
  ]
}
```

---

## How it works end-to-end

```
1. User installs the jinn-restore skill (copy dir or `clawhub install jinn-restore`)
2. User creates/copies a blueprint JSON into ~/.jinn-restore/blueprints/
3. User sets up a cron in their agent host:
   "Every hour, run jinn-restore against ~/.jinn-restore/blueprints/moldbook-posting.json"

Then, every hour:

4. Host fires cron → starts agent session
5. Skill activates → agent reads the blueprint
6. Agent globs artifacts/ for past MEMORY and SITUATION files
7. Agent measures each invariant, writes measurement JSONs
8. Agent takes actions to restore violated invariants
9. Agent re-measures, writes updated measurement JSONs
10. Agent writes MEMORY artifacts (what it learned)
11. Agent writes SITUATION artifact (attempt summary)
12. Session ends. All state is JSON files on disk.

Attempt 2 reads Attempt 1's files.
Attempt 10 has 9 attempts of accumulated learnings.
```

---

## What we build

1. **`SKILL.md`** — The protocol (~120 lines of YAML frontmatter + markdown)
2. **`references/invariant-types.md`** — Detailed type reference (~50 lines)
3. **`references/file-conventions.md`** — Data directory structure (~40 lines)
4. **`blueprints/moldbook-posting.json`** — First blueprint (~25 lines)
5. **`scripts/init.sh`** — Creates the data directory (~5 lines)

**Total: ~240 lines.** No code beyond shell helpers. The entire protocol is a document that any agent can follow.

---

## What Step 0 validates

1. **The loop runs** via the host's cron. No custom infrastructure.
2. **Artifacts accumulate** as JSON files across attempts.
3. **Recognition works** — the agent reads past artifacts and adapts.
4. **Measurements track state** — we can inspect pass rate by reading measurement files.

**Gate**: The loop runs N times unattended. Attempt N's SITUATION artifact references MEMORY artifacts from prior attempts.

---

## What Step 0 does NOT include

- Embeddings / vector search (Step 1 — add a search script that uses embeddings)
- x402 server (Step 2 — serve artifacts to other nodes)
- 8004 registration (Step 2)
- 8183 delivery (Step 3)
- Token rewards (Step 3)
- Any running process or server

---

## Path to Step 1

When the artifact directory gets large enough that globbing + reading every file is slow, we add:

1. **An MCP server** (optional) that indexes artifacts in SQLite with FTS5 and vec0 for fast search
2. **Embeddings** generated on artifact creation
3. **A `latest.json` index** (already in the design) to avoid scanning all measurements

But for step 0 with tens or low hundreds of artifacts, files on disk are fine.
