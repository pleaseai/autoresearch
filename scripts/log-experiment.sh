#!/usr/bin/env bash
# Log an experiment result to autoresearch.jsonl with validated format.
# Usage: log-experiment.sh <run> <commit> <metric> <status> <description> [metrics_json]
#
# Arguments:
#   run          - Run number (integer)
#   commit       - 7-char git commit hash
#   metric       - Primary metric value (number)
#   status       - keep|discard|crash|checks_failed
#   description  - Brief description of the experiment
#   metrics_json - Optional JSON object of all metrics (default: {})
#
# Example:
#   log-experiment.sh 1 abc1234 1523 keep "baseline" '{"total_ms":1523,"compile_ms":420}'

set -euo pipefail

RUN="${1:?Usage: log-experiment.sh <run> <commit> <metric> <status> <description> [metrics_json]}"
COMMIT="${2:?Missing commit hash}"
METRIC="${3:?Missing metric value}"
STATUS="${4:?Missing status}"
DESCRIPTION="${5:?Missing description}"
METRICS_JSON="${6:-{}}"

# Validate status
case "$STATUS" in
  keep|discard|crash|checks_failed) ;;
  *) echo "Invalid status: $STATUS (must be keep|discard|crash|checks_failed)" >&2; exit 1 ;;
esac

# Validate metric is a number
if ! echo "$METRIC" | grep -qE '^-?[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?$'; then
  echo "Invalid metric value: $METRIC (must be a number)" >&2
  exit 1
fi

# Validate commit is 7 chars
if [ ${#COMMIT} -ne 7 ]; then
  echo "Warning: commit hash '$COMMIT' is not 7 characters" >&2
fi

# Get timestamp in milliseconds
TIMESTAMP=$(date +%s)000

# Build and append JSON line
echo "{\"run\":${RUN},\"commit\":\"${COMMIT}\",\"metric\":${METRIC},\"metrics\":${METRICS_JSON},\"status\":\"${STATUS}\",\"description\":\"${DESCRIPTION}\",\"timestamp\":${TIMESTAMP}}" >> autoresearch.jsonl
