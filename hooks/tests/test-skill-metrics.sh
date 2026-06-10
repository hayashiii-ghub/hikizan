#!/usr/bin/env bash
# Tests for skill-metrics.sh — records the invoked skill name into metrics,
# never blocks.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../scripts/skill-metrics.sh"

export HIKIZAN_METRICS_DIR="$(mktemp -d 2>/dev/null || echo /tmp/hz-skillm.$$)"
MF="$HIKIZAN_METRICS_DIR/metrics.jsonl"
: > "$MF" 2>/dev/null || true

fire() { printf '%s' "$1" | bash "$HOOK" >/dev/null 2>&1; }

fire "$(jq -nc '{tool_input:{skill:"hikizan:kouchiku"}, session_id:"t"}')"
assert_contains "skill field, prefix stripped" '"condition":"kouchiku"' "$(cat "$MF")"

fire "$(jq -nc '{tool_input:{name:"sadoku"}, session_id:"t"}')"
assert_contains "name fallback"               '"condition":"sadoku"'   "$(cat "$MF")"

fire "$(jq -nc '{tool_input:{command:"shiken"}, session_id:"t"}')"
assert_contains "command fallback"            '"condition":"shiken"'   "$(cat "$MF")"

fire "$(jq -nc '{tool_input:{}, session_id:"t"}')"
assert_contains "unknown when no field"       '"condition":"unknown"'  "$(cat "$MF")"

assert_contains "event is skill_invoked"      '"event":"skill_invoked"' "$(cat "$MF")"

# never emits a permission decision (exit 0, no stdout JSON)
OUT="$(printf '%s' "$(jq -nc '{tool_input:{skill:"tansaku"}, session_id:"t"}')" | bash "$HOOK" 2>/dev/null)"
assert_eq "no decision emitted" "allow" "$(hz_decision_of "$OUT")"

rm -rf "$HIKIZAN_METRICS_DIR"
hz_test_summary
