#!/usr/bin/env bash
# Parse METRIC lines from autoresearch benchmark output.
# Usage: bash parse-metrics.sh <log-file>
# Output: JSON object with all metrics
#
# Example:
#   Input (from log file):
#     METRIC total_ms=1523
#     METRIC compile_ms=420
#   Output:
#     {"total_ms":1523,"compile_ms":420}

set -euo pipefail

LOG_FILE="${1:?Usage: parse-metrics.sh <log-file>}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo '{}' >&2
  exit 1
fi

# Extract METRIC lines and build JSON
metrics=$(grep "^METRIC " "$LOG_FILE" 2>/dev/null | sed 's/^METRIC //' || true)

if [[ -z "$metrics" ]]; then
  echo '{}' >&2
  exit 1
fi

# Build JSON object
echo -n "{"
first=true
while IFS='=' read -r name value; do
  if [[ "$first" == "true" ]]; then
    first=false
  else
    echo -n ","
  fi
  echo -n "\"$name\":$value"
done <<< "$metrics"
echo "}"
