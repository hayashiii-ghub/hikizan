#!/usr/bin/env bash
# Pin test for session-context.sh (SessionStart hook). Nothing else exercises
# this script; if it breaks, the per-session conventions injection goes
# silently missing with no test failure to catch it.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
SCRIPT="$DIR/../scripts/session-context.sh"
ROOT="$DIR/../.."

# keep test runs off the real metrics file
export HIKIZAN_METRICS_DIR="$(mktemp -d)"

PREAMBLE_LINE1="$(head -1 "$ROOT/context/standard-preamble.md")"

# standard tier (default)
OUT="$(printf '{}' | env CLAUDE_PLUGIN_ROOT="$ROOT" bash "$SCRIPT")"
CODE=$?
assert_exit "standard tier: exit code" 0 "$CODE"
assert_contains "standard tier: conventions header" "## hikizan Conventions" "$OUT"
assert_contains "standard tier: preamble line 1 present" "$PREAMBLE_LINE1" "$OUT"
assert_contains "standard tier: tier line" "hikizan-tier (this session): standard" "$OUT"

# guided tier — preamble is standard-only and must not appear
OUT="$(printf '{}' | env CLAUDE_PLUGIN_ROOT="$ROOT" HIKIZAN_TIER=guided bash "$SCRIPT")"
CODE=$?
assert_exit "guided tier: exit code" 0 "$CODE"
assert_contains "guided tier: conventions header" "## hikizan Conventions" "$OUT"
case "$OUT" in
  *"$PREAMBLE_LINE1"*)
    HZ_FAIL=$((HZ_FAIL + 1))
    printf '  FAIL: guided tier: preamble line 1 must NOT be present\n'
    ;;
  *) HZ_PASS=$((HZ_PASS + 1)) ;;
esac
assert_contains "guided tier: tier line" "hikizan-tier (this session): guided" "$OUT"

# no CLAUDE_PLUGIN_ROOT -> noop
OUT="$(printf '{}' | env -u CLAUDE_PLUGIN_ROOT bash "$SCRIPT")"
CODE=$?
assert_exit "no plugin root: exit code" 0 "$CODE"
assert_eq "no plugin root: stdout empty" "" "$OUT"

# empty stdin must not break the script (closed/empty stdin)
OUT="$(: | env CLAUDE_PLUGIN_ROOT="$ROOT" bash "$SCRIPT")"
CODE=$?
assert_exit "empty stdin: exit code" 0 "$CODE"

hz_test_summary
