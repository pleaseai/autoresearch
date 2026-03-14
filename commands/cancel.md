---
name: cancel
description: Cancel the active autoresearch experiment loop.
disable-model-invocation: true
---

# Cancel Autoresearch

Stop the active autoresearch experiment loop.

## Instructions

1. Remove the `.autoresearch-active` flag file:

```bash
rm -f .autoresearch-active
```

2. Report the final status:
   - Read `autoresearch.jsonl` to count total runs, kept, discarded, crashed
   - Show the best metric achieved
   - Show the current git branch and last kept commit

3. Display a summary:

```
Autoresearch session stopped.

Total runs: N (K kept, D discarded, C crashed)
Best metric: X.XX (commit abc1234)
Branch: autoresearch/<tag>

To resume later, run /autoresearch:run
To view full history, run /autoresearch:status
```
