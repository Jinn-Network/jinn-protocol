# File Conventions

All data lives in `~/.jinn-restore/` as plain JSON files.

## Directory structure

```
~/.jinn-restore/
├── blueprints/                       # Invariant definitions
│   └── {name}.json
├── artifacts/                        # Learnings and attempt records
│   ├── mem_{timestamp}_{slug}.json   # MEMORY artifacts
│   └── sit_{timestamp}_{slug}.json   # SITUATION artifacts
├── measurements/                     # Invariant measurements
│   ├── {invariant_id}/
│   │   └── {timestamp}.json
│   └── latest.json                   # Latest measurement per invariant
└── attempts/                         # Attempt summaries
    └── {timestamp}.json
```

## Timestamp format

All timestamps in filenames use: `YYYY-MM-DDTHH-MM` (hyphens instead of
colons for filesystem compatibility). In JSON fields, use full ISO 8601:
`2026-03-11T10:00:00Z`.

## File schemas

### Blueprint (`blueprints/{name}.json`)

```json
{
  "name": "string",
  "description": "string",
  "invariants": [
    {
      "id": "string",
      "type": "FLOOR | CEILING | RANGE | BOOLEAN",
      "metric": "string (FLOOR/CEILING/RANGE)",
      "condition": "string (BOOLEAN)",
      "min": "number (FLOOR/RANGE)",
      "max": "number (CEILING/RANGE)",
      "assessment": "string",
      "examples": { "do": ["string"], "dont": ["string"] }
    }
  ]
}
```

### Measurement (`measurements/{invariant_id}/{timestamp}.json`)

```json
{
  "invariant_id": "string",
  "invariant_type": "FLOOR | CEILING | RANGE | BOOLEAN",
  "measured_value": "number (FLOOR/CEILING/RANGE)",
  "min_threshold": "number (FLOOR/RANGE)",
  "max_threshold": "number (CEILING/RANGE)",
  "passed": "boolean",
  "context": "string — what was measured and how",
  "timestamp": "ISO 8601"
}
```

### Latest measurements (`measurements/latest.json`)

```json
{
  "GOAL-EXAMPLE": {
    "passed": false,
    "measured_value": 0,
    "timestamp": "2026-03-11T10:00:00Z"
  }
}
```

### MEMORY artifact (`artifacts/mem_{timestamp}_{slug}.json`)

```json
{
  "type": "MEMORY",
  "invariant_id": "string (optional)",
  "name": "string",
  "content": "string — the actual learning",
  "tags": ["string"],
  "timestamp": "ISO 8601"
}
```

### SITUATION artifact (`artifacts/sit_{timestamp}_{slug}.json`)

```json
{
  "type": "SITUATION",
  "invariant_ids": ["string"],
  "status": "COMPLETED | RESTORED | FAILED | PARTIAL",
  "summary": "string — what happened in this attempt",
  "measurements_before": { "invariant_id": { "passed": "boolean", "value": "number" } },
  "measurements_after": { "invariant_id": { "passed": "boolean", "value": "number" } },
  "learnings_used": ["filename.json"],
  "timestamp": "ISO 8601"
}
```

### Attempt record (`attempts/{timestamp}.json`)

```json
{
  "id": "string",
  "blueprint": "string — blueprint name",
  "invariant_ids": ["string"],
  "status": "COMPLETED | RESTORED | FAILED | PARTIAL",
  "artifacts_created": ["filename.json"],
  "timestamp": "ISO 8601"
}
```
