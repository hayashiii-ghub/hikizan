#!/usr/bin/env bash
# CodexとCursorの配線・入出力を確認する。
# 共通Hookが各ハーネスの形式で正しく呼ばれることを保証するために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
CURSOR_HOOK="$ROOT/hooks/adapters/cursor/before-shell.sh"

run_cursor() {
  jq -nc --arg command "$1" '{command:$command,cwd:"/tmp",conversation_id:"test"}' |
    bash "$CURSOR_HOOK" 2>/dev/null
}
cursor_permission() {
  if [ -z "$1" ]; then echo allow; else printf '%s' "$1" | jq -r '.permission // "allow"'; fi
}

OUT=$(run_cursor 'gh pr merge 123')
assert_eq "Cursor denies PR merge" "deny" "$(cursor_permission "$OUT")"
OUT=$(run_cursor 'HIKIZAN_MERGE_APPROVED=1 gh pr merge 123')
assert_eq "Cursor allows approved PR merge" "allow" "$(cursor_permission "$OUT")"
OUT=$(run_cursor 'git push origin feature')
assert_eq "Cursor allows normal push" "allow" "$(cursor_permission "$OUT")"
OUT=$(run_cursor 'gh pr create --title x')
assert_eq "Cursor allows PR creation" "allow" "$(cursor_permission "$OUT")"

CODEX="$ROOT/hooks/adapters/codex/hooks.json"
jq empty "$CODEX" >/dev/null 2>&1
assert_exit "Codex hooks JSON is valid" 0 "$?"
assert_contains "Codex wires the merge hook" "pre-merge.sh deny Codex" "$(cat "$CODEX")"
assert_eq "Codex no longer wires removed floors" "" \
  "$(grep -Eo 'pre-(push|pr-create|destructive)\.sh' "$CODEX" || true)"

CURSOR="$ROOT/hooks/adapters/cursor/hooks.json"
jq empty "$CURSOR" >/dev/null 2>&1
assert_exit "Cursor hooks JSON is valid" 0 "$?"
assert_contains "Cursor registers sessionStart" "sessionStart" "$(cat "$CURSOR")"

hz_test_summary
