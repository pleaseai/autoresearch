# Architecture: Autoresearch

> Claude Code plugin for autonomous experiment loops. Modify code, benchmark, keep improvements, discard regressions, repeat forever.

## System Purpose

Autoresearch is a Claude Code plugin that automates iterative optimization of any measurable target. It creates a feedback loop where an AI agent modifies code, runs benchmarks, compares metrics, and keeps only improvements — discarding regressions automatically. The plugin is inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) (ML training optimization) and [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch) (domain-agnostic experiment loops).

The key architectural insight is the **agent re-spawn pattern**: instead of running experiments in a single long-lived session (which would overflow the context window), each batch of experiments runs in a fresh agent context. Session state persists through files (`autoresearch.md` and `autoresearch.jsonl`), and a Stop hook automatically triggers new agent spawns.

## Entry Points

| Entry Point | Purpose | When to Start Here |
|---|---|---|
| `commands/run.md` | Session setup and agent delegation | Understanding the setup/resume workflow |
| `agents/experiment-runner.md` | Core experiment loop logic | Understanding how experiments are executed |
| `hooks/hooks.json` | Hook registration and lifecycle | Understanding loop continuity mechanism |
| `skills/autoresearch/SKILL.md` | Protocol definitions (METRIC format, JSONL schema) | Understanding data formats and conventions |
| `.claude-plugin/plugin.json` | Plugin manifest | Understanding plugin metadata and registration |

## Module Structure

### `commands/` — User-Facing Slash Commands

Commands the user invokes directly. These are the plugin's public interface.

```
commands/
├── run.md       # /autoresearch:run — Setup session + spawn agent
├── status.md    # /autoresearch:status — Display results dashboard
└── cancel.md    # /autoresearch:cancel — Stop the loop gracefully
```

- `run.md`: Orchestrates the full lifecycle. In setup mode, asks the user about the optimization target, creates session files, and spawns the first `experiment-runner` agent. In resume mode, simply re-spawns the agent. Never runs experiments directly.
- `status.md`: Read-only. Parses `autoresearch.jsonl` and displays a summary table with run counts, best metric, and recent experiments.
- `cancel.md`: Removes the `.autoresearch-active` flag file, allowing the next Stop hook to let Claude stop normally.

### `agents/` — Subagent Definitions

```
agents/
└── experiment-runner.md   # Core experiment execution agent
```

The `experiment-runner` is the **execution unit** of the system. Key configuration:
- `maxTurns: 200` — bounded execution per spawn
- `skills: [autoresearch]` — preloaded session protocol knowledge
- `memory: project` — persists learnings across sessions
- `model: sonnet` — balances speed and capability

Each spawn reads state from files, runs multiple experiments, then exits. The Stop hook triggers the next spawn.

### `skills/` — Background Knowledge

```
skills/
└── autoresearch/
    ├── SKILL.md                    # Protocol definitions
    └── references/
        └── session-format.md       # autoresearch.md template
```

The skill defines:
- **METRIC output format**: `METRIC name=value` lines from benchmark scripts
- **JSONL log schema**: One JSON line per experiment run
- **Git integration protocol**: Branch naming, keep/discard via commit/reset
- **Session document template**: Structure for `autoresearch.md`

Set to `user-invocable: false` — this is background knowledge that Claude loads automatically, not a user command.

### `hooks/` — Event-Driven Lifecycle

```
hooks/
├── hooks.json                     # Hook registration
└── scripts/
    ├── stop-hook.sh               # Agent re-spawn trigger
    ├── session-start-hook.sh      # Session detection
    ├── pre-compact-hook.sh        # State preservation
    └── post-compact-hook.sh       # State re-injection
```

The hooks implement the **agent re-spawn loop**:

1. **Stop hook** (`stop-hook.sh`): When Claude tries to stop, checks `.autoresearch-active` flag. If active, blocks the stop and instructs Claude to spawn a new `experiment-runner` agent. Checks `stop_hook_active` to prevent infinite loops. Respects `--max-iterations` limit.

2. **SessionStart hook** (`session-start-hook.sh`): On `startup|resume`, detects existing `autoresearch.md` and informs Claude about the session state.

3. **PreCompact hook** (`pre-compact-hook.sh`): Before context compaction, injects critical state (best metric, run count, commit) as a system message to survive the compaction.

4. **Post-compact hook** (`post-compact-hook.sh`): After compaction (SessionStart `compact` matcher), re-injects state and reminds Claude to spawn the agent if session is active.

### `scripts/` — Utility Scripts

```
scripts/
└── parse-metrics.sh    # Extract METRIC lines as JSON
```

Parses benchmark output into a JSON object. Used by the agent during experiment evaluation.

## Data Flow

```
User → /autoresearch:run
  │
  ├─ Setup: Ask target, create branch, write autoresearch.md + autoresearch.sh
  ├─ Activate: echo "N" > .autoresearch-active
  └─ Spawn: experiment-runner agent
       │
       ├─ Read: autoresearch.md (scope, constraints)
       ├─ Read: autoresearch.jsonl (history, best metric)
       │
       ├─ LOOP (within turn budget):
       │    ├─ Edit code → git commit
       │    ├─ bash autoresearch.sh → autoresearch.run.log
       │    ├─ grep "^METRIC " → parse values
       │    ├─ Compare vs best → keep (advance) or discard (reset)
       │    ├─ Append to autoresearch.jsonl
       │    └─ Update autoresearch.md "What's Been Tried"
       │
       └─ Agent exits (turn budget)
            │
            Stop hook fires
            ├─ Check .autoresearch-active → active
            ├─ Check --max-iterations → not reached
            └─ Block stop → "Spawn experiment-runner again"
                 │
                 └─ New agent spawns (fresh context) → reads files → continues
```

## Session Files (Runtime)

These files are created in the **user's project directory** (not in the plugin):

| File | Tracked | Purpose |
|---|---|---|
| `autoresearch.md` | Yes | Session document — single source of truth |
| `autoresearch.sh` | Yes | Benchmark script — outputs METRIC lines |
| `autoresearch.checks.sh` | Yes | Quality gate script (optional) |
| `autoresearch.jsonl` | No | Experiment log — one JSON line per run |
| `autoresearch.run.log` | No | Last benchmark stdout/stderr |
| `autoresearch.checks.log` | No | Last checks stdout/stderr |
| `.autoresearch-active` | No | Loop active flag (contains max iterations) |

## Architecture Invariants

### DO

- Always delegate experiment execution to the `experiment-runner` agent — never run experiments from commands
- Always check `stop_hook_active` in the Stop hook to prevent infinite loops
- Always persist state through files (`autoresearch.md`, `.jsonl`) — never rely on in-memory state
- Always create a git branch (`autoresearch/<tag>`) before starting experiments
- Always commit before benchmarking, so discard = `git reset --hard HEAD~1`
- Keep the Stop hook fast (<10s timeout) — it runs on every Claude stop

### DO NOT

- Do not run experiments in the main conversation context — always use the agent
- Do not modify `autoresearch.jsonl` format — append-only, one JSON line per run
- Do not skip the `stop_hook_active` check — this causes infinite loops
- Do not track `.autoresearch-active` or `.jsonl` in git — they are runtime state
- Do not hardcode paths — use `${CLAUDE_PLUGIN_ROOT}` for plugin files, `$CLAUDE_PROJECT_DIR` for project files

## Cross-Cutting Concerns

### State Management

All state persists through files, not memory. This enables:
- Agent re-spawning with fresh context (no state loss)
- Session resumption across Claude Code restarts
- Human-readable experiment history

### Git Integration

Git serves as both version control and experiment management:
- **Branch**: `autoresearch/<tag>` isolates experiments from main
- **Commits**: Each experiment is committed before benchmarking
- **Keep**: Branch advances (commit stays)
- **Discard**: `git reset --hard HEAD~1` reverts cleanly

### Context Window Management

The agent re-spawn pattern prevents context overflow:
- Each agent spawn gets ~200 turns of fresh context
- PreCompact hook preserves critical state through compaction
- Post-compact hook re-injects state after compaction
- `autoresearch.md` "What's Been Tried" section carries institutional knowledge

### Metric Protocol

Benchmarks communicate results via stdout:
```
METRIC total_ms=1523
METRIC compile_ms=420
```
- First metric matching the primary name determines keep/discard
- All metrics are recorded in JSONL for analysis
- Non-zero exit code = crash (no METRIC output expected)
