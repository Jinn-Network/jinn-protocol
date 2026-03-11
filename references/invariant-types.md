# Invariant Types

Four types, discriminated on the `type` field.

## FLOOR

A metric that must stay above a minimum threshold.

```json
{
  "id": "GOAL-POST-FREQ",
  "type": "FLOOR",
  "metric": "posts_per_hour",
  "min": 1,
  "assessment": "How to measure and restore this invariant.",
  "examples": {
    "do": ["Check before acting", "Use batch APIs"],
    "dont": ["Post duplicates", "Ignore rate limits"]
  }
}
```

**Measurement**: `passed = measured_value >= min`

## CEILING

A metric that must stay below a maximum threshold.

```json
{
  "id": "GOAL-COST",
  "type": "CEILING",
  "metric": "cost_per_attempt_usd",
  "max": 0.50,
  "assessment": "Monitor inference costs per attempt."
}
```

**Measurement**: `passed = measured_value <= max`

## RANGE

A metric that must stay within a bounded window.

```json
{
  "id": "GOAL-TONE",
  "type": "RANGE",
  "metric": "formality_score",
  "min": 3,
  "max": 7,
  "assessment": "Content should be neither too casual nor too formal."
}
```

**Measurement**: `passed = measured_value >= min && measured_value <= max`

Validation: `min` must be less than `max`.

## BOOLEAN

A condition that must hold true.

```json
{
  "id": "GOAL-BUILD",
  "type": "BOOLEAN",
  "condition": "Site builds without errors",
  "assessment": "Run the build command and check exit code."
}
```

**Measurement**: `passed = true | false` (no `measured_value`)

## Common fields

All invariant types share:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier, e.g. `GOAL-POST-FREQ` |
| `type` | Yes | `FLOOR`, `CEILING`, `RANGE`, or `BOOLEAN` |
| `assessment` | Yes | How to evaluate and restore this invariant |
| `examples` | No | `{ do: string[], dont: string[] }` guidance |

ID prefix conventions (from Jinn's semantic layer system):
- `GOAL-*` — Primary mission objectives
- `COORD-*` — Coordination with other jobs/agents
- `QUAL-*` — Quality gates
- `SYS-*` — System operating principles
- `LEARN-*` — Learnings from past attempts
