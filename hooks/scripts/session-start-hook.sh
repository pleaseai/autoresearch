#!/usr/bin/env bash
# SessionStart hook: detects active autoresearch sessions and informs Claude.
set -euo pipefail

# Check if autoresearch session files exist in the project directory
if [ ! -f "$CLAUDE_PROJECT_DIR/autoresearch.md" ]; then
  exit 0
fi

# Session exists — build context summary
RUN_COUNT=0
BEST_METRIC=""
LAST_STATUS=""

if [ -f "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" ]; then
  RUN_COUNT=$(wc -l < "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" | tr -d ' ')
  LAST_STATUS=$(tail -1 "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

ACTIVE_FLAG=""
if [ -f "$CLAUDE_PROJECT_DIR/.autoresearch-active" ]; then
  ACTIVE_FLAG=" (loop active)"
fi

BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")

cat <<HOOKOUT
{
  "systemMessage": "[AUTORESEARCH] Session detected${ACTIVE_FLAG}. Branch: ${BRANCH}, Runs: ${RUN_COUNT}, Last status: ${LAST_STATUS:-none}. Run /autoresearch:run to resume or /autoresearch:status to view progress."
}
HOOKOUT
