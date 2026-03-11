# Agent Instructions

This repo defines the **Jinn Restoration Protocol** — an AgentSkills-compatible
skill that teaches any agent how to run invariant restoration loops.

## What this is

- A `SKILL.md` following the [AgentSkills spec](https://agentskills.io/specification)
- File conventions for artifacts, measurements, and attempts (plain JSON on disk)
- Blueprint JSON files defining invariants to restore
- Reference documentation for the protocol architecture

No code. No servers. No databases. The protocol is a document.

## Architecture

The skill is installed in any agent host (OpenClaw, Claude Code, Gemini CLI,
Codex CLI, Cursor — any AgentSkills-compatible platform). The host handles
cron, sessions, and tool access. The skill tells the agent what to do:

1. Read a blueprint (invariants to restore)
2. Search past artifacts for learnings (glob JSON files)
3. Measure current state of each invariant
4. Take actions to restore violated invariants
5. Record what it learned as artifacts for future attempts

All state lives as JSON files in a data directory (`~/.jinn-restore/`).

### How this fits into Jinn

```
jinn-protocol (this repo)        jinn-cli-agents (monorepo)
─────────────────────────        ──────────────────────────
The skill + protocol spec        Worker, Ponder, MCP tools,
                                 on-chain marketplace, OLAS
Runs on any agent host           staking, contract infra
(OpenClaw, Claude Code, etc.)
                                 Portable code (invariant types,
Blueprint JSON → agent           validator, renderer) originated
reads/writes JSON files          here and is referenced by the
                                 protocol's type definitions.
```

The protocol is designed to eventually connect to the on-chain layer
(8183 for job escrow, 8004 for artifact registration, x402 for artifact
serving) but Step 0 runs purely locally with files.

See `docs/architecture.md` for the full vision.

## Key files

| File | Purpose |
|------|---------|
| `SKILL.md` | The protocol. This is the product. |
| `references/` | Detailed docs loaded on demand by the agent |
| `blueprints/` | Example invariant definitions |
| `scripts/` | Shell helpers (init, etc.) |
| `docs/` | Architecture proposals and design docs |

## Rules

- **No infrastructure.** Do NOT add npm dependencies, MCP servers, databases,
  or running processes. The entire protocol must be expressible as files that
  any agent can read/write with standard tools (Read, Write, Glob, Bash).
- **Not Claude-specific.** Must work with any AgentSkills-compatible host.
  No CLAUDE.md references, no Anthropic SDK imports.
- **Keep SKILL.md concise.** Under 5000 tokens for the instruction body
  (AgentSkills recommendation). Use `references/` for detailed docs.
- **Blueprints are the interface.** Keep them simple and human-readable.
- **File naming uses timestamps** for natural ordering and dedup.
  Format: `{type}_{ISO-timestamp}_{slug}.json`

## Invariant types

Four types, discriminated union on `type` field:

| Type | Condition | Fields |
|------|-----------|--------|
| FLOOR | `measured_value >= min` | `metric`, `min`, `assessment` |
| CEILING | `measured_value <= max` | `metric`, `max`, `assessment` |
| RANGE | `min <= measured_value <= max` | `metric`, `min`, `max`, `assessment` |
| BOOLEAN | `passed === true` | `condition`, `assessment` |

## Related repos

- **[jinn-cli-agents](https://github.com/Jinn-Network/jinn-cli-agents)** (private) —
  Monorepo with worker, Ponder indexer, MCP tools, on-chain infrastructure.
  The invariant type system originated here (`jinn-node/src/worker/prompt/`).
- **[jinn-node](https://github.com/Jinn-Network/jinn-node)** — Standalone node
  package (subtree of jinn-cli-agents).
