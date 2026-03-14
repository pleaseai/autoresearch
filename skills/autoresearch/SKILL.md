---
name: autoresearch
description: >
  Autonomous experiment loop protocol — modify code, benchmark, keep or discard,
  repeat. Use when the user asks to "run autoresearch", "optimize in a loop",
  "autonomous experiment", "benchmark loop", "keep optimizing", "run experiments
  autonomously", or mentions iterative benchmarking, experiment loops, continuous
  improvement cycles, or autoresearch sessions. Also activates when autoresearch.md
  or autoresearch.jsonl files are present in the working directory.
user-invocable: false
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
| `autoresearch.ideas.md` | Ideas backlog (optional) — prioritized experiment ideas | Yes |
| `autoresearch.jsonl` | Experiment log — config line + one JSON line per run | No |
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

### Metric Direction

The `autoresearch.md` Metrics section MUST specify whether **lower** or **higher** is better for the primary metric. This determines the keep/discard decision:

- **lower is better** (e.g., latency, bundle size): keep if new < best
- **higher is better** (e.g., accuracy, throughput): keep if new > best

The direction is also stored in the JSONL config line for programmatic access.

### JSONL Log Format

The first line of `autoresearch.jsonl` is a **config line**:

```json
{"type":"config","name":"Optimize test speed","metricName":"total_ms","metricUnit":"ms","bestDirection":"lower"}
```

Subsequent lines are experiment results (one per run):

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

### Ideas Backlog (`autoresearch.ideas.md`)

Optional separate file for experiment ideas. Keeps ideas organized without cluttering the session document. Format:

```markdown
# Autoresearch Ideas

## High Priority
- [ ] Try WebAssembly for the hot path
- [ ] Profile memory allocation patterns

## Medium Priority
- [ ] Batch multiple templates in a single compile pass
- [ ] Experiment with different data structures for the cache

## Tried (move here after testing)
- [x] Async processing — failed, +5.1% overhead (Run #3)
- [x] Object pool — no measurable impact (Run #4)
```

If this file exists, the agent should read it during startup and use it to prioritize experiments. Move tried ideas to the "Tried" section after testing.

## Session Document Template

For the `autoresearch.md` template, see [`references/session-format.md`](${CLAUDE_SKILL_DIR}/references/session-format.md).

## Experiment Loop Protocol

```
LOOP FOREVER:
1. Review past results in autoresearch.jsonl
2. Check autoresearch.ideas.md for prioritized ideas (if it exists)
3. Form a hypothesis for improvement
4. Make a focused code change (one idea per experiment)
5. git add && git commit -m "<description>"
6. bash autoresearch.sh > autoresearch.run.log 2>&1
7. Parse METRIC lines from autoresearch.run.log
8. If no metrics found → status: crash, read error log
9. Compare primary metric to best known value (respect direction: lower/higher)
10. keep / discard / crash decision
11. If checks script exists and benchmark passed:
    bash autoresearch.checks.sh > autoresearch.checks.log 2>&1
    If checks fail → revert, status: checks_failed
12. Log result using: bash scripts/log-experiment.sh <args>
13. Update autoresearch.md with insights
14. Update autoresearch.ideas.md if applicable (mark tried ideas)
15. Continue
```

## Key Rules

- **Never stop** to ask for confirmation during the loop
- **One idea per experiment** — keep changes small and isolated
- **Primary metric is king** — only improve the primary metric to keep
- **Respect metric direction** — lower-is-better vs higher-is-better from autoresearch.md
- **Record everything** — crashes and discards are valuable data
- **Update session document** — track what works and what doesn't
- **Read error logs** on crash — attempt a fix in the next iteration
- **Simplicity criterion** — complexity cost must be justified by improvement magnitude

## Logging Experiments

Use the bundled script for consistent JSONL format:

```bash
bash scripts/log-experiment.sh <run> <commit> <metric> <status> "<description>" '<metrics_json>'
```

Example:

```bash
bash scripts/log-experiment.sh 2 def5678 1450 keep "optimize hot loop" '{"total_ms":1450,"compile_ms":380}'
```

## Parsing Metrics

Extract metrics from benchmark output:

```bash
grep "^METRIC " autoresearch.run.log | sed 's/^METRIC //' | while IFS='=' read -r name value; do
  echo "$name=$value"
done
```

## Additional Resources

### Reference Files
- **[`references/session-format.md`](${CLAUDE_SKILL_DIR}/references/session-format.md)** — Complete `autoresearch.md` template with all sections
