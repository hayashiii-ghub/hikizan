#!/usr/bin/env bash
# Cursor形式の入力で`gh pr merge`だけを止める。
# 共通のマージ判定をCursorの権限応答へ変換するために使う。

set -uo pipefail
LIB="$(cd "$(dirname "$0")/../../scripts/lib" && pwd)"
# shellcheck source=../../scripts/lib/pr-merge.sh
source "$LIB/pr-merge.sh"
# shellcheck source=../../scripts/lib/decision-cursor.sh
source "$LIB/decision-cursor.sh"
# shellcheck source=../../scripts/lib/guard.sh
source "$LIB/guard.sh"

hz_require_jq
JSON=$(cat)
CMD=$(printf '%s' "$JSON" | jq -r '.command // ""')
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

if hz_is_pr_merge "$CMD"; then
  hz_cursor_decision deny "PRマージは人間の確認が必要です。利用者へ実行を戻し、別のコマンドや経路で回避しないでください。"
  exit 0
fi

exit 0
