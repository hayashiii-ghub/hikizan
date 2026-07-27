#!/usr/bin/env bash
# `gh pr merge`の実行前に、確認または拒否の判断を返す。
# PRマージをエージェントだけで完了させず、人間へ戻すために使う。

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

if [ "$DECISION" = "ask" ]; then
  hz_decision ask "PRマージは変更を統合する操作です。内容と検査結果を確認してから実行してください。"
else
  hz_decision deny "PRマージは人間の確認が必要です。${HARNESS:-このハーネス}ではhookから確認を開けないため、利用者へ実行を戻してください。別のコマンドや経路で回避しないでください。"
fi
