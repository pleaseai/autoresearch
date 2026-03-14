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
/autoresearch
```

Claude will ask what you want to optimize, then create session files and start running experiments autonomously.

### Check status

```
/autoresearch-status
```

View the current session's progress, metrics, and experiment history.

## How It Works

1. **Setup** — Define optimization target, primary metric, files in scope, and constraints.
2. **Branch** — Create `autoresearch/<tag>` git branch for the session.
3. **Loop** — Autonomous cycle:
   - Analyze past results and form a hypothesis
   - Edit code with a focused change
   - `git commit`
   - Run benchmark (`autoresearch.sh`)
   - Parse `METRIC name=value` lines from output
   - **Keep** if primary metric improved (branch advances)
   - **Discard** if not improved (`git reset --hard`)
   - Log result to `autoresearch.jsonl`
   - Repeat forever

## Session Files

| File | Purpose | Git Tracked |
|------|---------|-------------|
| `autoresearch.md` | Session document — objective, metrics, scope, insights | Yes |
| `autoresearch.sh` | Benchmark script — outputs `METRIC name=value` lines | Yes |
| `autoresearch.checks.sh` | Quality gate script (optional) | Yes |
| `autoresearch.jsonl` | Experiment log — one JSON line per run | No |
| `autoresearch.run.log` | Last benchmark output | No |
| `autoresearch.checks.log` | Last checks output | No |

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
| `/autoresearch` | Start or resume an autonomous experiment loop |
| `/autoresearch-status` | Display session status and experiment history |
| `experiment-runner` agent | Autonomous experiment execution agent |
| `autoresearch` skill | Session format, METRIC protocol, git integration |
| `parse-metrics.sh` | Parse METRIC lines from benchmark output |

## License

MIT
