---
name: autoresearch
description: >
  This skill should be used when the user asks to "run autoresearch",
  "optimize X in a loop", "autonomous experiment", "benchmark loop",
  "keep optimizing", "run experiments autonomously", "autoresearch session",
  or mentions autonomous optimization, iterative benchmarking,
  experiment loops, or continuous improvement cycles.
version: 0.1.0
---

# Autoresearch — Autonomous Experiment Loop

Autonomous experiment loop inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) and [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch). Modify code, benchmark, keep improvements, discard regressions, repeat forever.

## Core Concepts

### Session Files

Every autoresearch session creates these files in the working directory:

| File | Purpose | Git tracked |
|------|---------|-------------|
| `autoresearch.md` | Session document — objective, metrics, scope, insights | Yes |
| `autoresearch.sh` | Benchmark script — outputs `METRIC name=value` lines | Yes |
| `autoresearch.checks.sh` | Quality gate script (optional) | Yes |
| `autoresearch.jsonl` | Experiment log — one JSON line per run | No |
| `autoresearch.run.log` | Last benchmark output | No |
| `autoresearch.checks.log` | Last checks output | No |

### METRIC Output Format

The benchmark script (`autoresearch.sh`) must output metrics in this format:

```
METRIC total_ms=1523
METRIC compile_ms=420
METRIC memory_mb=128.5
```

The first metric matching the configured primary metric name determines keep/discard decisions. All metrics are recorded for analysis.

### JSONL Log Format

Each experiment appends one JSON line to `autoresearch.jsonl`:

```json
{"run":1,"commit":"abc1234","metric":1523,"metrics":{"total_ms":1523,"compile_ms":420},"status":"keep","description":"baseline","timestamp":1700000000000}
{"run":2,"commit":"def5678","metric":1450,"metrics":{"total_ms":1450,"compile_ms":380},"status":"keep","description":"optimize hot loop with SIMD","timestamp":1700000300000}
{"run":3,"commit":"ghi9012","metric":1600,"metrics":{"total_ms":1600,"compile_ms":500},"status":"discard","description":"try async processing","timestamp":1700000600000}
```

Status values: `keep`, `discard`, `crash`, `checks_failed`

### Git Integration

- Create branch `autoresearch/<tag>` at session start
- Each experiment commits before benchmarking
- On `keep`: branch advances (commit stays)
- On `discard`/`crash`/`checks_failed`: `git reset --hard HEAD~1` (revert)
- The git branch is the authoritative record of kept experiments

## Session Document Template

For the `autoresearch.md` template, see `references/session-format.md`.

## Experiment Loop Protocol

```
LOOP FOREVER:
1. Review past results in autoresearch.jsonl
2. Form a hypothesis for improvement
3. Make a focused code change (one idea per experiment)
4. git add && git commit -m "<description>"
5. bash autoresearch.sh > autoresearch.run.log 2>&1
6. Parse METRIC lines from autoresearch.run.log
7. If no metrics found → status: crash, read error log
8. Compare primary metric to best known value
9. keep / discard / crash decision
10. If checks script exists and benchmark passed:
    bash autoresearch.checks.sh > autoresearch.checks.log 2>&1
    If checks fail → revert, status: checks_failed
11. Append result to autoresearch.jsonl
12. Update autoresearch.md with insights
13. Continue
```

## Key Rules

- **Never stop** to ask for confirmation during the loop
- **One idea per experiment** — keep changes small and isolated
- **Primary metric is king** — only improve the primary metric to keep
- **Record everything** — crashes and discards are valuable data
- **Update session document** — track what works and what doesn't
- **Read error logs** on crash — attempt a fix in the next iteration
- **Simplicity criterion** — complexity cost must be justified by improvement magnitude

## Parsing Metrics

To extract metrics from benchmark output:

```bash
grep "^METRIC " autoresearch.run.log | sed 's/^METRIC //' | while IFS='=' read -r name value; do
  echo "$name=$value"
done
```

## Additional Resources

### Reference Files
- **`references/session-format.md`** — Complete `autoresearch.md` template with all sections
