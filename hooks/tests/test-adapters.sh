#!/usr/bin/env bash
# CodexとCursorの起動情報の配線を確認する。
# ハーネス固有の設定へシェル実行前の判定が戻らないようにするために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."

CODEX="$ROOT/hooks/adapters/codex/hooks.json"
jq empty "$CODEX" >/dev/null 2>&1
assert_exit "Codex hooks JSON is valid" 0 "$?"
assert_eq "Codex exposes only SessionStart" '["SessionStart"]' \
  "$(jq -c '.hooks | keys' "$CODEX")"

CURSOR="$ROOT/hooks/adapters/cursor/hooks.json"
jq empty "$CURSOR" >/dev/null 2>&1
assert_exit "Cursor hooks JSON is valid" 0 "$?"
assert_eq "Cursor exposes only sessionStart" '["sessionStart"]' \
  "$(jq -c '.hooks | keys' "$CURSOR")"

hz_test_summary
