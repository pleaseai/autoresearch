---
name: run
description: Start or resume an autonomous experiment loop for any optimization target.
disable-model-invocation: true
argument-hint: "[optimization target] [--max-iterations N]"
---

# Autoresearch — Autonomous Experiment Loop

Set up and run an autonomous experiment loop for any measurable optimization target.

## Setup Phase

If no `autoresearch.md` session document exists in the working directory:

1. **Ask the user** what to optimize:
   - What is the optimization target? (e.g., "execution speed", "bundle size", "test coverage", "model accuracy")
   - What command measures the target? (e.g., `npm run bench`, `python train.py`, `cargo bench`)
   - What is the primary metric name and unit? (e.g., `total_ms`, `bundle_kb`, `accuracy_pct`)
   - Is lower or higher better?
   - What files are in scope for modification?
   - What files/directories are off-limits?
   - Any constraints? (e.g., "tests must pass", "no new dependencies")

2. **Create a git branch**: `autoresearch/<descriptive-tag>`

3. **Read source files** in scope to understand the codebase.

4. **Create session files**:
   - `autoresearch.md` — session document (see Skill("autoresearch") for template)
   - `autoresearch.sh` — benchmark script that outputs `METRIC name=value` lines
   - `autoresearch.checks.sh` (optional) — quality gate script if constraints require it

5. **Run baseline**: Execute the benchmark, record initial metrics, commit as baseline.

6. **Activate the loop**: Create `.autoresearch-active` flag file.
   - If `$ARGUMENTS` includes `--max-iterations N`, write `N` to the flag file.
   - Otherwise write `0` (unlimited).

```bash
echo "0" > .autoresearch-active
```

7. **Spawn the experiment-runner agent** to begin the loop.

## Resume Phase

If `autoresearch.md` and `autoresearch.jsonl` already exist:

1. **Re-activate the loop**: Create `.autoresearch-active` flag file if not present.
2. **Spawn the experiment-runner agent** to continue from where it left off.

The agent reads `autoresearch.md` and `autoresearch.jsonl` to reconstruct state automatically.

## How the Loop Works

```
/autoresearch:run
  → Setup (if needed) + activate flag
  → Spawn experiment-runner agent
  → Agent runs N experiments with fresh context
  → Agent exits (turn budget reached)
  → Stop hook detects active session
  → Stop hook instructs: "Spawn experiment-runner again"
  → New agent spawns with fresh context
  → Reads autoresearch.md + .jsonl to resume
  → Repeat until /autoresearch:cancel or --max-iterations reached
```

Each agent spawn gets a **fresh context window**, so the loop can run hundreds of iterations without context overflow.

## Important Rules

- **Delegate to agent**: Do NOT run the experiment loop directly. Always spawn the `experiment-runner` agent.
- A **Stop hook** automatically triggers re-spawning of the agent when it exits.
- The loop continues until the user runs `/autoresearch:cancel` or `--max-iterations` is reached.
- To cancel: run `/autoresearch:cancel` which removes the `.autoresearch-active` flag.
