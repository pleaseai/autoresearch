#!/usr/bin/env bash
# Stop hook: prevents Claude from stopping during an active autoresearch session.
# If autoresearch is active (flag file exists + session files present),
# blocks the stop and re-injects the loop prompt.
set -euo pipefail

FLAG_FILE="$CLAUDE_PROJECT_DIR/.autoresearch-active"

# If no active flag, allow stop
if [ ! -f "$FLAG_FILE" ]; then
  exit 0
fi

# Check if session files exist
if [ ! -f "$CLAUDE_PROJECT_DIR/autoresearch.md" ]; then
  # Session file missing, clean up flag and allow stop
  rm -f "$FLAG_FILE"
  exit 0
fi

# Check max iterations
MAX_ITERATIONS=$(cat "$FLAG_FILE" 2>/dev/null | head -1)
if [ -z "$MAX_ITERATIONS" ] || [ "$MAX_ITERATIONS" = "0" ]; then
  MAX_ITERATIONS=0  # unlimited
fi

# Count current iterations from JSONL
CURRENT=0
if [ -f "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" ]; then
  CURRENT=$(wc -l < "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" | tr -d ' ')
fi

# If max iterations reached, allow stop
if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$CURRENT" -ge "$MAX_ITERATIONS" ]; then
  rm -f "$FLAG_FILE"
  exit 0
fi

# Block stop and re-inject the autoresearch loop prompt
cat <<'HOOKOUT'
{
  "decision": "block",
  "reason": "Autoresearch session is active. Continue the experiment loop: read autoresearch.md and autoresearch.jsonl to resume from where you left off. Analyze past results, form a new hypothesis, implement a focused change, benchmark, and keep or discard based on the primary metric. Do NOT stop until the session is cancelled with /autoresearch:cancel."
}
HOOKOUT
