#!/usr/bin/env bash
# Without jq a hook cannot parse its stdin, so the PreToolUse floors would
# silently allow everything (fail-open) unless each entry point guards for it.
# This file runs every hook with jq removed from PATH and pins fail-closed
# (exit 2 + stderr mentioning jq) for the guarded scripts.
#
# NOTE: this file must never call jq itself (directly or via lib/harness.sh's
# hz_run_hook), so the check holds regardless of whether the ambient
# environment has jq installed.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"

SHIM="$(mktemp -d)"
ln -s "$(command -v dirname)" "$SHIM/dirname"
# (script が guard 到達前に必要とする外部コマンドは dirname のみ。増えたら symlink を足す)

run_nojq() { # <script path> -> sets HZ_CODE / HZ_ERR
  local errf; errf="$(mktemp)"
  printf '{}' | env PATH="$SHIM" /bin/bash "$1" >/dev/null 2>"$errf"
  HZ_CODE=$?; HZ_ERR=$(cat "$errf"); rm -f "$errf"
}

run_nojq "$DIR/../scripts/pre-push.sh"
assert_eq "pre-push.sh fails closed (exit 2)" "2" "$HZ_CODE"
assert_contains "pre-push.sh stderr mentions jq" "jq" "$HZ_ERR"

run_nojq "$DIR/../scripts/pre-destructive.sh"
assert_eq "pre-destructive.sh fails closed (exit 2)" "2" "$HZ_CODE"
assert_contains "pre-destructive.sh stderr mentions jq" "jq" "$HZ_ERR"

run_nojq "$DIR/../scripts/pre-pr-create.sh"
assert_eq "pre-pr-create.sh fails closed (exit 2)" "2" "$HZ_CODE"
assert_contains "pre-pr-create.sh stderr mentions jq" "jq" "$HZ_ERR"

run_nojq "$DIR/../adapters/cursor/before-shell.sh"
assert_eq "before-shell.sh fails closed (exit 2)" "2" "$HZ_CODE"
assert_contains "before-shell.sh stderr mentions jq" "jq" "$HZ_ERR"

rm -rf "$SHIM"
hz_test_summary
