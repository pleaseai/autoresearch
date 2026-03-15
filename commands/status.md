---
name: status
description: Display the current autoresearch session status, results summary, and experiment history.
allowed-tools: Read, Grep, Glob, Bash
---

# Autoresearch Status

Display the current status of the autoresearch session.

## Instructions

1. **Check for session files**:
   - If `autoresearch.md` does not exist, report "No active autoresearch session."
   - If `autoresearch.jsonl` does not exist, report "Session exists but no experiments recorded yet."

2. **Read `autoresearch.md`** for session context (objective, metrics, scope).

3. **Compute status** using the shared script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/compute-status.sh"
```

This returns a JSON object with all computed metrics. Parse the output to populate the tables below.

If the script is unavailable, parse `autoresearch.jsonl` manually:
   - Total runs, Kept / Discarded / Crashed / Checks-failed counts
   - Baseline metric (first experiment), Best metric (direction-aware best of kept runs)
   - Improvement percentage, Elapsed time, Experiment rate

4. **Display a summary table**:

```
## Autoresearch Status

**Objective**: <from autoresearch.md>
**Branch**: autoresearch/<tag>
**Primary Metric**: <name> (<unit>, <direction> is better)

### Session Info
| Stat | Value |
|------|-------|
| Status | 🟢 Active / ⚪ Inactive |
| Elapsed | Xh Ym |
| Experiment Rate | N.N / hour |
| Max Iterations | N / unlimited |

### Progress
| Stat | Value |
|------|-------|
| Total Runs | N |
| Kept | N |
| Discarded | N |
| Crashed | N |
| Checks Failed | N |

### Metrics
| | Value | vs Baseline |
|---|---|---|
| Baseline | X.XX | — |
| Best | Y.YY | -Z.Z% |

### Trend (last 10 runs)
| Window | Kept | Discarded | Avg Metric |
|--------|------|-----------|------------|
| Last 5 | N | N | X.XX |
| Previous 5 | N | N | Y.YY |

### Recent Experiments
| # | Commit | Metric | Status | Description |
|---|--------|--------|--------|-------------|
| ... | ... | ... | ... | ... |
```

5. **Compute trend**: Split the last 10 experiments into two windows of 5. For each window, count kept/discarded and compute average metric value. This shows whether optimization is still finding improvements or plateauing.

6. **If the user wants to resume**, suggest running `/autoresearch:run` to continue.
