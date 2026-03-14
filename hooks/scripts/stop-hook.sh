#!/usr/bin/env bash
# Stop hook: re-spawns experiment-runner agent when autoresearch session is active.
# pi-autoresearch pattern: each agent spawn gets fresh context.
# Includes cooldown to prevent rapid re-spawns and API cost spikes.
set -euo pipefail

INPUT=$(cat)

# CRITICAL: Prevent infinite loop. If stop_hook_active is true,
# this is a re-entry from a previous stop hook block — allow stop.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

FLAG_FILE="$CLAUDE_PROJECT_DIR/.autoresearch-active"
COOLDOWN_FILE="$CLAUDE_PROJECT_DIR/.autoresearch-last-spawn"
COOLDOWN_SECONDS=30  # minimum seconds between agent re-spawns

# If no active flag, allow stop
if [ ! -f "$FLAG_FILE" ]; then
  exit 0
fi

# Check if session files exist
if [ ! -f "$CLAUDE_PROJECT_DIR/autoresearch.md" ]; then
  rm -f "$FLAG_FILE" "$COOLDOWN_FILE"
  exit 0
fi

# Check max iterations
MAX_ITERATIONS=$(head -1 "$FLAG_FILE" 2>/dev/null || echo "0")
if [ -z "$MAX_ITERATIONS" ]; then
  MAX_ITERATIONS=0
fi

# Count current iterations from JSONL
CURRENT=0
if [ -f "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" ]; then
  CURRENT=$(wc -l < "$CLAUDE_PROJECT_DIR/autoresearch.jsonl" | tr -d ' ')
fi

# If max iterations reached, allow stop and clean up
if [ "$MAX_ITERATIONS" -gt 0 ] 2>/dev/null && [ "$CURRENT" -ge "$MAX_ITERATIONS" ] 2>/dev/null; then
  rm -f "$FLAG_FILE" "$COOLDOWN_FILE"
  exit 0
fi

# Cooldown check: prevent rapid re-spawns
NOW=$(date +%s)
if [ -f "$COOLDOWN_FILE" ]; then
  LAST_SPAWN=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "0")
  ELAPSED=$((NOW - LAST_SPAWN))
  if [ "$ELAPSED" -lt "$COOLDOWN_SECONDS" ]; then
    REMAINING=$((COOLDOWN_SECONDS - ELAPSED))
    # Allow stop during cooldown — user can /autoresearch:run to resume
    exit 0
  fi
fi

# Record spawn time for cooldown tracking
echo "$NOW" > "$COOLDOWN_FILE"

# Block stop and instruct to spawn a fresh experiment-runner agent
cat <<HOOKOUT
{
  "decision": "block",
  "reason": "Autoresearch session is active (run ${CURRENT}/${MAX_ITERATIONS:-unlimited}). Spawn the experiment-runner agent to continue the experiment loop. The agent will read autoresearch.md and autoresearch.jsonl to resume with fresh context. Do NOT run experiments directly — always delegate to the experiment-runner agent."
}
HOOKOUT
