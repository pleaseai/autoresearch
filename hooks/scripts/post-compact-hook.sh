#!/usr/bin/env bash
# Post-compact hook (SessionStart:compact): re-injects autoresearch state after context compaction.
# Ensures the main session knows to re-spawn the experiment-runner agent.
set -euo pipefail

# Only run if autoresearch session is active
if [ ! -f "$CLAUDE_PROJECT_DIR/autoresearch.md" ]; then
  exit 0
fi

# Use shared status computation
STATUS_JSON=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/compute-status.sh" 2>/dev/null || echo "{}")

BRANCH=$(echo "$STATUS_JSON" | jq -r '.branch // "unknown"')
TOTAL=$(echo "$STATUS_JSON" | jq -r '.totalRuns // 0')
KEPT=$(echo "$STATUS_JSON" | jq -r '.kept // 0')
DISCARDED=$(echo "$STATUS_JSON" | jq -r '.discarded // 0')
CRASHED=$(echo "$STATUS_JSON" | jq -r '.crashed // 0')
BEST=$(echo "$STATUS_JSON" | jq -r '.bestMetric // "none"')
METRIC_NAME=$(echo "$STATUS_JSON" | jq -r '.metricName // "metric"')
IMPROVEMENT=$(echo "$STATUS_JSON" | jq -r '.improvementPct // "0"')
RATE=$(echo "$STATUS_JSON" | jq -r '.experimentsPerHour // "0"')
MAX=$(echo "$STATUS_JSON" | jq -r '.maxIterations // 0')
ACTIVE=$(echo "$STATUS_JSON" | jq -r '.active // false')

MAX_DISPLAY="unlimited"
[ "$MAX" -gt 0 ] 2>/dev/null && MAX_DISPLAY="$MAX"

ACTIVE_MSG=""
if [ "$ACTIVE" = "true" ]; then
  ACTIVE_MSG=" Session is ACTIVE — spawn experiment-runner agent to continue."
fi

echo "[AUTORESEARCH] Context was compacted. Branch: ${BRANCH} | Run ${TOTAL}/${MAX_DISPLAY} (${KEPT} kept, ${DISCARDED} discarded, ${CRASHED} crashed) | Best ${METRIC_NAME}: ${BEST} (${IMPROVEMENT}% from baseline) | Rate: ${RATE}/hr.${ACTIVE_MSG}"
