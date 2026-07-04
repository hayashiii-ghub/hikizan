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
#   event:      "hook_fired" | "command_executed"
#   hook:       "pre-push" | "pre-pr-create" | "pre-destructive" | "post-command" | "session-context"
#   condition:  "nff" | "force_protected" | "no_draft_no_reviewer" | "destructive" |
#               "submodule_unpushed" | "inject" | "noop" | "none"
#   decision:   "allow" | "block" | "ask" | "warn"
#   session_id: CC session id (from hook stdin JSON), or "" when unavailable
#
# Rotation: size-based, keyed off HIKIZAN_METRICS_MAX_BYTES (default 1MB).
# When metrics.jsonl exceeds the threshold it is moved to metrics.jsonl.1
# (one previous generation kept, then overwritten) before the new line is
# appended, so the file never grows unbounded.

hikizan_metrics_log() {
  local event="${1:-hook_fired}"
  local hook="${2:-unknown}"
  local condition="${3:-none}"
  local decision="${4:-allow}"
  local session_id="${5:-}"

  local dir="${HIKIZAN_METRICS_DIR:-$HOME/.hikizan}"
  local file="$dir/metrics.jsonl"

  mkdir -p "$dir" 2>/dev/null || return 0

  # size-based rotation: keep one previous generation so the file cannot grow
  # unbounded. Silent like every other failure mode here.
  local max="${HIKIZAN_METRICS_MAX_BYTES:-1048576}"
  if [ -f "$file" ]; then
    local size
    size=$(wc -c < "$file" 2>/dev/null | tr -d ' ') || size=0
    case "$size" in ''|*[!0-9]*) size=0 ;; esac
    if [ "$size" -gt "$max" ] 2>/dev/null; then
      mv "$file" "$file.1" 2>/dev/null || :
    fi
  fi

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
