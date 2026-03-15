#!/usr/bin/env bash
# SessionStart hook: detects active autoresearch sessions and informs Claude.
set -euo pipefail

# Check if autoresearch session files exist in the project directory
if [ ! -f "$CLAUDE_PROJECT_DIR/autoresearch.md" ]; then
  exit 0
fi

# Use shared status computation
STATUS_JSON=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/compute-status.sh" 2>/dev/null || echo "{}")

BRANCH=$(echo "$STATUS_JSON" | jq -r '.branch // "unknown"')
TOTAL=$(echo "$STATUS_JSON" | jq -r '.totalRuns // 0')
KEPT=$(echo "$STATUS_JSON" | jq -r '.kept // 0')
DISCARDED=$(echo "$STATUS_JSON" | jq -r '.discarded // 0')
BEST=$(echo "$STATUS_JSON" | jq -r '.bestMetric // "none"')
METRIC_NAME=$(echo "$STATUS_JSON" | jq -r '.metricName // "metric"')
IMPROVEMENT=$(echo "$STATUS_JSON" | jq -r '.improvementPct // "0"')
RATE=$(echo "$STATUS_JSON" | jq -r '.experimentsPerHour // "0"')
ACTIVE=$(echo "$STATUS_JSON" | jq -r '.active // false')

ACTIVE_FLAG=""
if [ "$ACTIVE" = "true" ]; then
  ACTIVE_FLAG=" (loop active)"
fi

MSG="[AUTORESEARCH] Session detected${ACTIVE_FLAG}. Branch: ${BRANCH} | ${TOTAL} runs (${KEPT} kept, ${DISCARDED} discarded) | Best ${METRIC_NAME}: ${BEST} (${IMPROVEMENT}% from baseline) | Rate: ${RATE}/hr. Run /autoresearch:run to resume or /autoresearch:status to view progress."

jq -n --arg msg "$MSG" '{"systemMessage": $msg}'
