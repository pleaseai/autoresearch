#!/usr/bin/env bash
# Compute autoresearch session status from JSONL and state files.
# Outputs a JSON object to stdout. Used by hooks and commands.
# Requires: jq, $CLAUDE_PROJECT_DIR
set -euo pipefail

JSONL="$CLAUDE_PROJECT_DIR/autoresearch.jsonl"
FLAG="$CLAUDE_PROJECT_DIR/.autoresearch-active"

# Defaults
ACTIVE=false
TOTAL_RUNS=0
KEPT=0
DISCARDED=0
CRASHED=0
CHECKS_FAILED=0
METRIC_NAME="metric"
METRIC_UNIT=""
BEST_DIRECTION="lower"
BASELINE_METRIC=null
BEST_METRIC=null
IMPROVEMENT_PCT=0
FIRST_TS=0
LAST_TS=0
ELAPSED=0
RATE=0
MAX_ITERATIONS=0
BRANCH="unknown"
RECENT_RUNS="[]"

# Active flag
if [ -f "$FLAG" ]; then
  ACTIVE=true
  MAX_ITERATIONS=$(sed -n '1p' "$FLAG" 2>/dev/null || echo "0")
  [ -z "$MAX_ITERATIONS" ] && MAX_ITERATIONS=0
fi

# Branch
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")

# Parse JSONL
if [ -f "$JSONL" ]; then
  # Config line (first line)
  CONFIG=$(head -1 "$JSONL")
  METRIC_NAME=$(echo "$CONFIG" | jq -r '.metricName // "metric"')
  METRIC_UNIT=$(echo "$CONFIG" | jq -r '.metricUnit // ""')
  BEST_DIRECTION=$(echo "$CONFIG" | jq -r '.bestDirection // "lower"')

  # Experiment lines (skip config)
  EXPERIMENTS=$(tail -n +2 "$JSONL")

  if [ -n "$EXPERIMENTS" ]; then
    TOTAL_RUNS=$(echo "$EXPERIMENTS" | wc -l | tr -d ' ')
    KEPT=$(echo "$EXPERIMENTS" | grep -c '"status":"keep"' || true)
    DISCARDED=$(echo "$EXPERIMENTS" | grep -c '"status":"discard"' || true)
    CRASHED=$(echo "$EXPERIMENTS" | grep -c '"status":"crash"' || true)
    CHECKS_FAILED=$(echo "$EXPERIMENTS" | grep -c '"status":"checks_failed"' || true)

    # Baseline = first experiment
    BASELINE_METRIC=$(echo "$EXPERIMENTS" | head -1 | jq '.metric')

    # Best metric from kept runs (direction-aware)
    KEPT_LINES=$(echo "$EXPERIMENTS" | grep '"status":"keep"' || true)
    if [ -n "$KEPT_LINES" ]; then
      if [ "$BEST_DIRECTION" = "lower" ]; then
        BEST_METRIC=$(echo "$KEPT_LINES" | jq -s 'min_by(.metric) | .metric')
      else
        BEST_METRIC=$(echo "$KEPT_LINES" | jq -s 'max_by(.metric) | .metric')
      fi
    fi

    # Improvement %
    if [ "$BASELINE_METRIC" != "null" ] && [ "$BEST_METRIC" != "null" ] && [ "$BASELINE_METRIC" != "0" ]; then
      IMPROVEMENT_PCT=$(echo "$BEST_METRIC $BASELINE_METRIC" | awk '{printf "%.1f", (($1 - $2) / $2) * 100}')
    fi

    # Timestamps
    FIRST_TS=$(echo "$EXPERIMENTS" | head -1 | jq '.timestamp // 0')
    LAST_TS=$(echo "$EXPERIMENTS" | tail -1 | jq '.timestamp // 0')
    NOW_MS=$(date +%s)000
    if [ "$FIRST_TS" -gt 0 ] 2>/dev/null; then
      ELAPSED=$(( (NOW_MS - FIRST_TS) / 1000 ))
      if [ "$ELAPSED" -gt 0 ]; then
        RATE=$(echo "$TOTAL_RUNS $ELAPSED" | awk '{printf "%.1f", $1 / ($2 / 3600)}')
      fi
    fi

    # Recent runs (last 5)
    RECENT_RUNS=$(echo "$EXPERIMENTS" | tail -5 | jq -s '.')
  fi
fi

# Output JSON
jq -n \
  --argjson active "$ACTIVE" \
  --argjson totalRuns "$TOTAL_RUNS" \
  --argjson kept "$KEPT" \
  --argjson discarded "$DISCARDED" \
  --argjson crashed "$CRASHED" \
  --argjson checksFailed "$CHECKS_FAILED" \
  --arg metricName "$METRIC_NAME" \
  --arg metricUnit "$METRIC_UNIT" \
  --arg bestDirection "$BEST_DIRECTION" \
  --argjson baselineMetric "${BASELINE_METRIC:-null}" \
  --argjson bestMetric "${BEST_METRIC:-null}" \
  --arg improvementPct "$IMPROVEMENT_PCT" \
  --argjson elapsedSeconds "$ELAPSED" \
  --arg experimentsPerHour "$RATE" \
  --argjson maxIterations "$MAX_ITERATIONS" \
  --arg branch "$BRANCH" \
  --argjson recentRuns "$RECENT_RUNS" \
  '{
    active: $active,
    totalRuns: $totalRuns,
    kept: $kept,
    discarded: $discarded,
    crashed: $crashed,
    checksFailed: $checksFailed,
    metricName: $metricName,
    metricUnit: $metricUnit,
    bestDirection: $bestDirection,
    baselineMetric: $baselineMetric,
    bestMetric: $bestMetric,
    improvementPct: $improvementPct,
    elapsedSeconds: $elapsedSeconds,
    experimentsPerHour: $experimentsPerHour,
    maxIterations: $maxIterations,
    branch: $branch,
    recentRuns: $recentRuns
  }'
