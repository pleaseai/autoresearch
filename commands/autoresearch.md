---
name: autoresearch
description: Start or resume an autonomous experiment loop for any optimization target.
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

6. **Start the experiment loop** (see below).

## Resume Phase

If `autoresearch.md` and `autoresearch.jsonl` already exist:

1. **Read** `autoresearch.md` for session context.
2. **Read** `autoresearch.jsonl` to reconstruct state (best metric, run count, last commit).
3. **Check git status** to ensure clean working tree.
4. **Continue the experiment loop** from where it left off.

## Experiment Loop

```
LOOP FOREVER:
1. Analyze current code and past results to form a hypothesis
2. Edit files in scope with an experimental change
3. git add -A && git commit -m "<description>"
4. Run: bash autoresearch.sh > autoresearch.run.log 2>&1
5. Parse METRIC lines from output
6. If no METRIC lines → crash. Read tail of log for error.
7. Compare primary metric against best known value
8. If improved:
   - Status: keep
   - Update best known value
   - Append to autoresearch.jsonl
   - Update "What's Been Tried" in autoresearch.md
9. If not improved:
   - Status: discard
   - Append to autoresearch.jsonl
   - git reset --hard HEAD~1
10. If checks script exists and benchmark passed:
    - Run: bash autoresearch.checks.sh > autoresearch.checks.log 2>&1
    - If checks fail: revert and log as checks_failed
11. Log progress summary
12. Continue to next iteration
```

## Important Rules

- **NEVER stop to ask for confirmation** during the loop — run autonomously until interrupted.
- **Keep changes small and focused** — one idea per experiment.
- **Track everything** in `autoresearch.jsonl` — every run, including crashes and discards.
- **Update `autoresearch.md`** with key insights and tried approaches.
- If a crash occurs, read the error log and attempt a fix in the next iteration.
- Aim for the simplest change that improves the metric.
