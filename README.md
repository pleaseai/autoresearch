# Autoresearch

Autonomous experiment loop plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Modify code, benchmark, keep improvements, discard regressions, repeat forever.

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) and [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch).

## Install

```bash
claude plugin add pleaseai/autoresearch
```

Or for local development:

```bash
claude --plugin-dir /path/to/autoresearch
```

## Usage

### Start a session

```
/autoresearch:run
```

Claude will ask what you want to optimize, then create session files and start running experiments autonomously. A **Stop hook** keeps the loop running — Claude won't stop until you cancel.

### With max iterations

```
/autoresearch:run --max-iterations 20
```

### Check status

```
/autoresearch:status
```

View the current session's progress, metrics, and experiment history.

### Cancel the loop

```
/autoresearch:cancel
```

Stop the experiment loop gracefully. Claude will finish the current iteration and then stop.

## How It Works

```
/autoresearch:run
  → Setup (ask target, create branch, create session files)
  → Activate .autoresearch-active flag
  → Spawn experiment-runner agent (fresh context)
  → Agent runs experiments autonomously
  → Agent exits (turn budget reached)
  → Stop hook detects active session
  → Stop hook: "Spawn experiment-runner again"
  → New agent spawns with fresh context
  → Reads autoresearch.md + .jsonl to resume
  → Repeat until /autoresearch:cancel or --max-iterations
```

Each agent spawn gets a **fresh context window** (inspired by [pi-autoresearch](https://github.com/davebcn87/pi-autoresearch)), so the loop can run hundreds of iterations without context overflow. Session state persists through `autoresearch.md` and `autoresearch.jsonl`.

### Experiment Cycle (per agent spawn)

1. Read session state from `autoresearch.md` + `autoresearch.jsonl`
2. Form hypothesis based on past results
3. Implement focused code change → `git commit`
4. Run benchmark (`autoresearch.sh`) → parse `METRIC` lines
5. **Keep** if metric improved, **Discard** if not → `git reset --hard`
6. Log result to `autoresearch.jsonl`, update `autoresearch.md`
7. Repeat within turn budget

## Session Files

| File | Purpose | Git Tracked |
|------|---------|-------------|
| `autoresearch.md` | Session document — objective, metrics, scope, insights | Yes |
| `autoresearch.sh` | Benchmark script — outputs `METRIC name=value` lines | Yes |
| `autoresearch.checks.sh` | Quality gate script (optional) | Yes |
| `autoresearch.jsonl` | Experiment log — one JSON line per run | No |
| `autoresearch.run.log` | Last benchmark output | No |
| `autoresearch.checks.log` | Last checks output | No |
| `.autoresearch-active` | Loop active flag (max iterations) | No |

## Benchmark Script

The benchmark script must output metrics in this format:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Run your benchmark
echo "METRIC total_ms=1523"
echo "METRIC compile_ms=420"
echo "METRIC memory_mb=128.5"
```

## JSONL Log Format

Each experiment is logged as one JSON line:

```json
{"run":1,"commit":"abc1234","metric":1523,"metrics":{"total_ms":1523,"compile_ms":420},"status":"keep","description":"baseline","timestamp":1700000000000}
```

Status values: `keep`, `discard`, `crash`, `checks_failed`

## Plugin Components

| Component | Description |
|-----------|-------------|
| `/autoresearch:run` | Start or resume an autonomous experiment loop |
| `/autoresearch:status` | Display session status and experiment history |
| `/autoresearch:cancel` | Cancel the active experiment loop |
| `experiment-runner` agent | Autonomous experiment execution agent |
| `autoresearch` skill | Session format, METRIC protocol, git integration |
| Stop hook | Re-spawn agent when it exits during active session |
| SessionStart hook | Detect existing sessions on startup/resume |
| PreCompact hook | Preserve session state before context compaction |
| Post-compact hook | Re-inject state after context compaction |
| `parse-metrics.sh` | Parse METRIC lines from benchmark output |

## License

MIT
