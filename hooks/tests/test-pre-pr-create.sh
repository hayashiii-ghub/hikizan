#!/usr/bin/env bash
# Integration tests for pre-pr-create.sh — a non-draft PR with no reviewer is
# denied; draft (--draft or -d) or a reviewer is allowed. Covers L1 (-d short
# flag) and the JSON-decision migration.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../scripts/pre-pr-create.sh"

hz_run_hook "$HOOK" "gh pr create --title x --body y" "/tmp"
assert_eq "bare create -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "gh pr create --draft" "/tmp"
assert_eq "--draft -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "gh pr create -d" "/tmp"
assert_eq "-d short flag -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "gh pr create --reviewer @octocat" "/tmp"
assert_eq "--reviewer -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "gh pr create -r @octocat" "/tmp"
assert_eq "-r short flag -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git status" "/tmp"
assert_eq "non-pr command -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "gh pr create" "/tmp"
assert_contains "deny reason mentions reviewer" "reviewer" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

hz_test_summary
