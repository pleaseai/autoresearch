# autoresearch — autonomous experiment loop for Claude Code

**[Install](#install)** · **[Usage](#usage)** · **[How it works](#how-it-works)**

*Try an idea, measure it, keep what works, discard what doesn't, repeat forever.*

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) and [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch). Works for any optimization target: test speed, bundle size, LLM training, build times, Lighthouse scores.

---

## What's included

| | |
|---|---|
| **Commands** | `/autoresearch:run`, `/autoresearch:status`, `/autoresearch:cancel` |
| **Agent** | `experiment-runner` — autonomous experiment execution |
| **Skill** | Session protocol, METRIC format, git integration |
| **Hooks** | Stop (loop continuity), SessionStart, PreCompact, PostCompact |

---

## Install

```bash
claude plugin add pleaseai/autoresearch
```

<details>
<summary>Local development</summary>

```bash
claude --plugin-dir /path/to/autoresearch
```

</details>

---

## Usage

### 1. Start autoresearch

```
/autoresearch:run
```

Claude asks about your goal, command, metric, and files in scope. It then creates a branch, writes `autoresearch.md` and `autoresearch.sh`, runs the baseline, and starts looping immediately.

```
/autoresearch:run --max-iterations 20
```

Use `--max-iterations` as a safety net.

### 2. The loop

The agent runs autonomously: edit → commit → benchmark → keep or revert → repeat. It never stops unless interrupted.

Every result is appended to `autoresearch.jsonl` — one line per run. This means:

- **Survives restarts** — the agent can resume a session by reading the file
- **Survives context resets** — `autoresearch.md` captures what's been tried so a fresh agent has full context
- **Human readable** — open it anytime to see the full history
- **Branch-aware** — each session runs on `autoresearch/<tag>` branch

### 3. Monitor progress

```
/autoresearch:status
```

Shows run count, kept/discarded/crashed stats, best metric, and recent experiments.

### 4. Cancel

```
/autoresearch:cancel
```

Stops the loop gracefully. The current iteration finishes, then Claude stops normally.

---

## Example domains

| Domain | Metric | Command |
|--------|--------|---------|
| Test speed | seconds ↓ | `npm test` |
| Bundle size | KB ↓ | `npm run build && du -sb dist` |
| LLM training | val_bpb ↓ | `uv run train.py` |
| Build speed | seconds ↓ | `cargo build --release` |
| Lighthouse | perf score ↑ | `lighthouse http://localhost:3000 --output=json` |
| API latency | p99_ms ↓ | `wrk -t4 -c100 -d10s http://localhost:8080/api` |

---

## How it works

The **agent** is the execution unit. The **commands** orchestrate. The **hooks** keep the loop alive. The **skill** provides protocol knowledge.

```
┌──────────────────────────┐     ┌──────────────────────────┐
│  Commands + Hooks        │     │  Agent + Skill            │
│  (infrastructure)        │     │  (execution)              │
│                          │     │                           │
│  /autoresearch:run       │────►│  experiment-runner        │
│  Stop hook (re-spawn)    │     │  reads autoresearch.md    │
│  SessionStart (detect)   │     │  edits code, benchmarks   │
│  PreCompact (preserve)   │     │  keeps or discards        │
│                          │     │  logs to .jsonl           │
└──────────────────────────┘     └──────────────────────────┘
```

### Agent re-spawn pattern

Each batch of experiments runs in a **fresh agent context**. When the agent exits (turn budget reached), the Stop hook blocks Claude from stopping and instructs it to spawn a new agent. The new agent reads `autoresearch.md` and `autoresearch.jsonl` to resume exactly where the previous one left off.

This means the loop can run **hundreds of iterations** without context window overflow.

```
/autoresearch:run
  → Spawn experiment-runner agent (fresh context)
  → Agent runs N experiments
  → Agent exits
  → Stop hook: "Spawn experiment-runner again"
  → New agent (fresh context) reads files, continues
  → Repeat until /autoresearch:cancel or --max-iterations
```

### Session files

Two files keep the session alive across restarts and context resets:

| File | Purpose | Git |
|------|---------|-----|
| `autoresearch.md` | Living document — objective, what's been tried, dead ends, key wins | Tracked |
| `autoresearch.sh` | Benchmark script — outputs `METRIC name=value` lines | Tracked |
| `autoresearch.checks.sh` | Quality gate checks (optional) | Tracked |
| `autoresearch.jsonl` | Append-only log — metric, status, commit, description per run | Untracked |
| `.autoresearch-active` | Loop active flag (contains max iterations count) | Untracked |

A fresh agent with no memory can read these files and continue exactly where the previous session left off.

---

## Benchmark script

The benchmark script must output metrics as `METRIC name=value` lines:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Run your benchmark
result=$(npm test -- --reporter=json 2>&1 | jq '.testResults[0].perfStats.runtime')
echo "METRIC test_ms=$result"
```

The first metric matching the configured primary metric determines keep/discard. All metrics are recorded.

---

## Backpressure checks (optional)

Create `autoresearch.checks.sh` to run correctness checks (tests, types, lint) after every passing benchmark. This ensures optimizations don't break things.

```bash
#!/usr/bin/env bash
set -euo pipefail
npm test --reporter=dot 2>&1 | tail -50
npx tsc --noEmit 2>&1 | tail -20
```

- If the file doesn't exist, the loop runs without checks
- If it exists, it runs automatically after every passing benchmark
- Check time does **not** affect the primary metric
- If checks fail, the experiment is logged as `checks_failed` and reverted

---

## JSONL log format

Each experiment is one JSON line:

```json
{"run":1,"commit":"abc1234","metric":1523,"metrics":{"total_ms":1523,"compile_ms":420},"status":"keep","description":"baseline","timestamp":1700000000000}
```

Status values: `keep`, `discard`, `crash`, `checks_failed`

---

## Plugin components

| Component | Description |
|-----------|-------------|
| `/autoresearch:run` | Start or resume the experiment loop |
| `/autoresearch:status` | Display session status and history |
| `/autoresearch:cancel` | Stop the loop gracefully |
| `experiment-runner` agent | Autonomous experiment execution (fresh context per spawn) |
| `autoresearch` skill | METRIC protocol, JSONL schema, session document format |
| Stop hook | Re-spawn agent when it exits during active session |
| SessionStart hook | Detect existing sessions on startup/resume |
| PreCompact hook | Preserve session state before context compaction |
| PostCompact hook | Re-inject state after context compaction |

---

## License

MIT
