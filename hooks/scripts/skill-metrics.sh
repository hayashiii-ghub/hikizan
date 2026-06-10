#!/usr/bin/env bash
# PreToolUse hook for the Skill tool. Records which skill was invoked so routing
# accuracy can be evaluated from data (L3) — never blocks, never asks.
#
# The skill name is stored in the metrics `condition` field, e.g.
#   {"event":"skill_invoked","hook":"skill-metrics","condition":"kouchiku",...}
# Aggregate with:
#   jq -r 'select(.hook=="skill-metrics") | .condition' ~/.hikizan/metrics.jsonl \
#     | sort | uniq -c

set -uo pipefail
HERE="$(dirname "$0")"

# shellcheck source=lib/metrics.sh
source "$HERE/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }

JSON=$(cat)
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""')
# The Skill tool input field name varies; try the common keys in order.
NAME=$(printf '%s' "$JSON" | jq -r '.tool_input.skill // .tool_input.name // .tool_input.command // ""')
[ -z "$NAME" ] && NAME="unknown"
NAME="${NAME#hikizan:}"   # strip namespace prefix for cleaner aggregation

hikizan_metrics_log skill_invoked skill-metrics "$NAME" invoke "$SESSION_ID"
exit 0
