# Autoresearch Session Document Format

The `autoresearch.md` file is the single source of truth for a session. A fresh agent reads it to resume with full context.

## Template

```markdown
# Autoresearch: <goal>

## Objective
<Specific description of what is being optimized and the workload.>

## Metrics
- **Primary**: <name> (<unit>, **lower** is better)  ← MUST specify lower or higher
- **Secondary**: <name>, <name>, ...
- **Direction**: lower ← Used by agent to determine keep/discard

## How to Run
`./autoresearch.sh` — outputs `METRIC name=number` lines.

## Files in Scope
<Every file the agent may modify, with a brief note on what each does.>
- `src/engine.ts` — core rendering engine
- `src/compiler.ts` — template compiler

## Off Limits
<What must NOT be touched.>
- `src/types.ts` — shared type definitions
- `tests/` — test files (referenced by checks, not modified)
- `package.json` — no dependency changes

## Constraints
<Hard rules that must be followed.>
- All tests must pass (enforced by `autoresearch.checks.sh`)
- No new dependencies
- Must maintain backward compatibility
- TypeScript strict mode must stay enabled

## What's Been Tried
<Updated as experiments accumulate. Key wins, dead ends, and architectural insights.>

### Successful Changes
- **Run #2** (abc1234): Optimize hot loop with SIMD — total_ms 1523→1450 (-4.8%)
- **Run #5** (mno3456): Cache compiled templates — total_ms 1380→1290 (-6.5%)

### Failed Approaches
- **Run #3**: Async processing — increased overhead, total_ms +5.1%
- **Run #4**: Reduce allocations with object pool — no measurable impact

### Insights
- The hot loop in `engine.ts:142-180` dominates execution time
- Template compilation is the second bottleneck
- Async approaches add too much overhead for this workload size

## Ideas Backlog
<Optional: ideas to try in future iterations.>
- [ ] Try WebAssembly for the hot path
- [ ] Profile memory allocation patterns
- [ ] Batch multiple templates in a single compile pass
```

## Section Guidelines

### Objective
Be specific about the workload, not just the goal. "Optimize API response time for the /users endpoint under 1000 concurrent connections" is better than "make it faster."

### Files in Scope
List every file the agent may modify. Keep it focused — the fewer files, the more reviewable the diffs.

### Off Limits
Explicitly state untouchable files. Include the reason if not obvious.

### Constraints
Hard rules that override optimization. If tests must pass, say so. If no new deps, say so.

### What's Been Tried
This is the most important section for session continuity. Update it after every significant experiment. Include:
- Run number and commit hash for traceability
- Brief description of the change
- Quantitative result (metric values and delta)
- Why it worked or didn't

### Ideas Backlog
Optional but recommended. Helps the agent prioritize experiments and avoids repeating failed approaches from different angles.

## Benchmark Script Template (`autoresearch.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Pre-checks (fast, <1s)
# e.g., syntax check, type check

# Run the benchmark
# Capture the metric you care about

# Output METRIC lines (parsed by the agent)
echo "METRIC total_ms=$result"
echo "METRIC compile_ms=$compile_time"
echo "METRIC memory_mb=$peak_memory"
```

Rules:
- Must use `set -euo pipefail`
- Must output `METRIC name=value` lines to stdout
- Keep it fast — every second is multiplied by hundreds of runs
- Non-zero exit code = crash

## Checks Script Template (`autoresearch.checks.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Run quality gates
# Only create this if constraints require it

# Example: run tests
npm test --reporter=dot 2>&1 | tail -50

# Example: type checking
npx tsc --noEmit 2>&1 | tail -20
```

Rules:
- Only create when user constraints require it
- Runs after every passing benchmark
- Check duration does NOT count toward the primary metric
- Non-zero exit code = checks_failed (experiment reverted)
- Suppress verbose success output, only show errors
