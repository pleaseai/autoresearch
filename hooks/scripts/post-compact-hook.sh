#!/usr/bin/env bash
# Post-compact hook (SessionStart:compact): re-injects autoresearch state after context compaction.
# Ensures the main session knows to re-spawn the experiment-runner agent.
set -euo pipefail

# Only run if autoresearch session is active
if [ ! -f "$CLAUDE_PROJECT_DIR/autoresearch.md" ]; then
  exit 0
fi

RUN_COUNT=0
BEST_METRIC=""
BEST_COMMIT=""
ACTIVE=""

if [ -f "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" ]; then
  RUN_COUNT=$(wc -l < "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" | tr -d ' ')

  BEST_LINE=$(grep '"status":"keep"' "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" 2>/dev/null | tail -1 || true)
  if [ -n "$BEST_LINE" ]; then
    BEST_METRIC=$(echo "$BEST_LINE" | grep -o '"metric":[0-9.e+-]*' | head -1 | cut -d: -f2)
    BEST_COMMIT=$(echo "$BEST_LINE" | grep -o '"commit":"[^"]*"' | head -1 | cut -d'"' -f4)
  fi
fi

if [ -f "$CLAUDE_PROJECT_DIR/.autoresearch-active" ]; then
  ACTIVE=" Session is ACTIVE — spawn experiment-runner agent to continue."
fi

BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")

echo "[AUTORESEARCH] Context was compacted. Branch: ${BRANCH}, Runs: ${RUN_COUNT}, Best: ${BEST_METRIC:-none} (${BEST_COMMIT:-none}).${ACTIVE}"
