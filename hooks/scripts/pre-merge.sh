#!/usr/bin/env bash
# `gh pr merge`の実行前に、承認済みか確認して判断を返す。
# 未承認のPRマージを止め、明示承認後の再実行だけを許可するために使う。

set -uo pipefail
HERE="$(dirname "$0")"
DECISION="ask"
HARNESS="${2:-}"
if [ "${1:-}" = "deny" ]; then
  DECISION="deny"
fi

# shellcheck source=lib/decision.sh
source "$HERE/lib/decision.sh"
# shellcheck source=lib/guard.sh
source "$HERE/lib/guard.sh"
# shellcheck source=lib/pr-merge.sh
source "$HERE/lib/pr-merge.sh"

hz_require_jq
JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')

hz_is_pr_merge "$COMMAND" || exit 0
hz_has_merge_approval "$COMMAND" && exit 0

if [ "$DECISION" = "ask" ]; then
  hz_decision ask "PRマージは変更を統合する操作です。対象と検査結果を確認し、このマージを明示的に承認してください。"
else
  hz_decision deny "PRマージには利用者の明示承認が必要です。${HARNESS:-このハーネス}ではhookから確認を開けないため、対象PRの承認を求めてください。承認前に回避せず、承認後だけHIKIZAN_MERGE_APPROVED=1を同じマージコマンドへ付けて再実行できます。"
fi
