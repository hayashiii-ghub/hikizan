#!/usr/bin/env bash
# Integration tests for pre-destructive.sh — destructive commands must ask,
# benign ones must pass through.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../scripts/pre-destructive.sh"

hz_run_hook "$HOOK" "rm -rf build" "/tmp"
assert_eq "rm -rf -> ask" "ask" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git reset --hard HEAD~1" "/tmp"
assert_eq "reset --hard -> ask" "ask" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git clean -fd" "/tmp"
assert_eq "git clean -fd -> ask" "ask" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "ls -la" "/tmp"
assert_eq "ls -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git status" "/tmp"
assert_eq "git status -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "rm -rf node_modules" "/tmp"
assert_contains "ask reason is human-readable" "irreversible" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

# quote-aware floors: quoting the flag must not smuggle a literal quote
# character past the anchored checks and skip the ask.
hz_run_hook "$HOOK" 'rm "-rf" /tmp/x' "/tmp"
assert_eq "quoted rm -rf -> ask" "ask" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" 'git reset "--hard"' "/tmp"
assert_eq "quoted git reset --hard -> ask" "ask" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" 'if true; then rm -rf /tmp/x; fi' "/tmp"
assert_eq "reserved-word wrapped rm -rf -> ask" "ask" "$(hz_decision_of "$HZ_OUT")"

hz_test_summary
