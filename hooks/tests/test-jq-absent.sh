#!/usr/bin/env bash
# jqがない環境で、PRマージHookが判定不能として終了することを確認する。
# 入力を解析できない状態でマージを黙って許可しないために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"

SHIM=$(mktemp -d)
ln -s "$(command -v dirname)" "$SHIM/dirname"

run_nojq() {
  local error_file
  error_file=$(mktemp)
  printf '{}' | env PATH="$SHIM" /bin/bash "$1" >/dev/null 2>"$error_file"
  HZ_CODE=$?
  HZ_ERR=$(cat "$error_file")
  rm -f "$error_file"
}

run_nojq "$DIR/../scripts/pre-merge.sh"
assert_eq "pre-merge fails closed without jq" "2" "$HZ_CODE"
assert_contains "pre-merge explains missing jq" "jq" "$HZ_ERR"

run_nojq "$DIR/../adapters/cursor/before-shell.sh"
assert_eq "Cursor adapter fails closed without jq" "2" "$HZ_CODE"
assert_contains "Cursor adapter explains missing jq" "jq" "$HZ_ERR"

rm -rf "$SHIM"
hz_test_summary
