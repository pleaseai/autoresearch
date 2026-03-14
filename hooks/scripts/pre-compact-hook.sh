#!/usr/bin/env bash
# PreCompact hook: preserves autoresearch state before context compaction.
# Outputs critical session info so it survives the compaction.
set -euo pipefail

# Only run if autoresearch session exists
if [ ! -f "$CLAUDE_PROJECT_DIR/autoresearch.md" ]; then
  exit 0
fi

# Gather current state
RUN_COUNT=0
BEST_METRIC=""
BEST_COMMIT=""
LAST_DESCRIPTION=""

if [ -f "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" ]; then
  RUN_COUNT=$(wc -l < "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" | tr -d ' ')

  # Extract best kept result (last "keep" entry)
  BEST_LINE=$(grep '"status":"keep"' "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" | tail -1 2>/dev/null || true)
  if [ -n "$BEST_LINE" ]; then
    BEST_METRIC=$(echo "$BEST_LINE" | grep -o '"metric":[0-9.]*' | head -1 | cut -d: -f2)
    BEST_COMMIT=$(echo "$BEST_LINE" | grep -o '"commit":"[^"]*"' | head -1 | cut -d'"' -f4)
  fi

  # Last experiment description
  LAST_DESCRIPTION=$(tail -1 "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" 2>/dev/null | grep -o '"description":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")

cat <<HOOKOUT
{
  "systemMessage": "[AUTORESEARCH STATE] Branch: ${BRANCH} | Total runs: ${RUN_COUNT} | Best metric: ${BEST_METRIC:-none} (commit: ${BEST_COMMIT:-none}) | Last experiment: ${LAST_DESCRIPTION:-none}. Read autoresearch.md and autoresearch.jsonl to continue the experiment loop."
}
HOOKOUT
