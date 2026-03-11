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
  homepage: https://github.com/Jinn-Network/jinn-protocol
---

# Jinn Restoration Protocol

You are running a restoration attempt. Your job is to restore the invariants
defined in a blueprint to their target state.

## Setup

The data directory defaults to `~/.jinn-restore/`. If it doesn't exist:

```bash
mkdir -p ~/.jinn-restore/{artifacts,measurements,attempts,blueprints}
```

## Workflow

### 1. Read the blueprint

Load the blueprint JSON provided in the prompt or at the path specified.
It defines invariants. See `references/invariant-types.md` for the type system.

### 2. Search for past learnings

Glob `~/.jinn-restore/artifacts/mem_*.json` for MEMORY artifacts and
`~/.jinn-restore/artifacts/sit_*.json` for SITUATION artifacts from past
attempts. Look for entries whose `invariant_id` matches your blueprint's
invariants, or whose `tags` are relevant. Prioritize recent files (filename
contains timestamp). Read the `content` field for learnings.

### 3. Measure before acting

For each invariant, assess its current state. Write a measurement JSON to
`~/.jinn-restore/measurements/{invariant_id}/{timestamp}.json`:

```json
{
  "invariant_id": "GOAL-EXAMPLE",
  "invariant_type": "FLOOR",
  "measured_value": 0,
  "min_threshold": 1,
  "passed": false,
  "context": "Description of what was measured and how",
  "timestamp": "2026-03-11T10:00:00Z"
}
```

Update `~/.jinn-restore/measurements/latest.json` with the latest per invariant.

If all invariants pass, report **COMPLETED** and stop.

### 4. Restore

Take whatever actions are needed to bring violated invariants back into bounds.
Use any available tools. The blueprint's `assessment` field describes how.

### 5. Measure after acting

Re-measure each invariant you attempted to restore. Write new measurement files.

### 6. Record learnings

Write MEMORY artifacts for anything you learned to
`~/.jinn-restore/artifacts/mem_{timestamp}_{slug}.json`:

```json
{
  "type": "MEMORY",
  "invariant_id": "GOAL-EXAMPLE",
  "name": "descriptive-slug",
  "content": "Specific learning: what worked, failed, or should be tried next.",
  "tags": ["relevant", "keywords"],
  "timestamp": "2026-03-11T10:15:00Z"
}
```

Be specific. Future attempts will read these files.

### 7. Record the attempt

Write a SITUATION artifact to `~/.jinn-restore/artifacts/sit_{timestamp}_attempt.json`
and an attempt record to `~/.jinn-restore/attempts/{timestamp}.json`.

See `references/file-conventions.md` for the full schemas.

### 8. Stop

One attempt = one session. The host handles re-dispatch.

## Terminal states

End your response with exactly one of:

- **COMPLETED** — All invariants already in bounds
- **RESTORED** — Invariants were violated, actions taken, now in bounds
- **FAILED** — Could not restore; explain why
- **PARTIAL** — Some invariants restored, others still violated

## Invariant types (quick reference)

| Type | Passes when |
|------|-------------|
| FLOOR | `measured_value >= min` |
| CEILING | `measured_value <= max` |
| RANGE | `min <= measured_value <= max` |
| BOOLEAN | `passed === true` |
