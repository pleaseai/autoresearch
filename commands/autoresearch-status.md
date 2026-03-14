---
name: autoresearch-status
description: Display the current autoresearch session status, results summary, and experiment history.
---

# Autoresearch Status

Display the current status of the autoresearch session.

## Instructions

1. **Check for session files**:
   - If `autoresearch.md` does not exist, report "No active autoresearch session."
   - If `autoresearch.jsonl` does not exist, report "Session exists but no experiments recorded yet."

2. **Read `autoresearch.md`** for session context (objective, metrics, scope).

3. **Parse `autoresearch.jsonl`** and compute:
   - Total runs
   - Kept / Discarded / Crashed / Checks-failed counts
   - Baseline metric (first kept run)
   - Best metric (best kept run)
   - Improvement percentage from baseline to best
   - Last 10 experiment entries

4. **Display a summary table**:

```
## Autoresearch Status

**Objective**: <from autoresearch.md>
**Branch**: autoresearch/<tag>
**Primary Metric**: <name> (<unit>, <direction> is better)

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

### Recent Experiments
| # | Commit | Metric | Status | Description |
|---|--------|--------|--------|-------------|
| ... | ... | ... | ... | ... |
```

5. **If the user wants to resume**, suggest running `/autoresearch` to continue.
