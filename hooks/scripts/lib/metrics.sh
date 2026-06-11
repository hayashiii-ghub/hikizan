#!/usr/bin/env bash
# hikizan metrics writer.
#
# Append one JSONL event to $HIKIZAN_METRICS_DIR/metrics.jsonl (default
# ~/.hikizan/metrics.jsonl). Silent on every failure mode (missing jq,
# unwritable dir, etc.) so a metrics problem never breaks the hook
# itself.
#
# Usage:
#   source "$(dirname "$0")/lib/metrics.sh"
#   hikizan_metrics_log <event> <hook> <condition> <decision> <session_id>
#
# Schema (one JSON object per line):
#   ts:         RFC3339 UTC timestamp
#   event:      "hook_fired" (extend later as needed)
#   hook:       "pre-push" | "pre-pr-create" | "pre-destructive" | "post-commit" | "session-context"
#   condition:  "nff" | "force_protected" | "no_draft_no_reviewer" |
#               "submodule_unpushed" | "create" | "append" | "noop" | "none"
#   decision:   "allow" | "block" | "ask" | "warn" | "invoke"
#   session_id: CC session id (from hook stdin JSON), or "" when unavailable

hikizan_metrics_log() {
  local event="${1:-hook_fired}"
  local hook="${2:-unknown}"
  local condition="${3:-none}"
  local decision="${4:-allow}"
  local session_id="${5:-}"

  local dir="${HIKIZAN_METRICS_DIR:-$HOME/.hikizan}"
  local file="$dir/metrics.jsonl"

  mkdir -p "$dir" 2>/dev/null || return 0

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || return 0

  command -v jq >/dev/null 2>&1 || return 0

  local line
  line=$(jq -nc \
    --arg ts "$ts" \
    --arg event "$event" \
    --arg hook "$hook" \
    --arg condition "$condition" \
    --arg decision "$decision" \
    --arg session_id "$session_id" \
    '{ts: $ts, event: $event, hook: $hook, condition: $condition, decision: $decision, session_id: $session_id}' 2>/dev/null) || return 0

  printf '%s\n' "$line" >> "$file" 2>/dev/null || return 0
}
