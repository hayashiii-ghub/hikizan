#!/usr/bin/env bash
# Claude CodeとCodexへ、生成済みのスキル選択規則を渡す。
# 起動時の接続だけを扱い、Git状態の取得やネットワーク操作を持ち込まないために使う。

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROUTING="$ROOT/hooks/routing.md"
CONTEXT=""
[ ! -f "$ROUTING" ] || CONTEXT=$(cat "$ROUTING")

case "${1:-}" in
  claude)
    printf '%s\n' "$CONTEXT"
    ;;
  codex)
    command -v jq >/dev/null 2>&1 || exit 0
    jq -nc --arg context "$CONTEXT" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$context}}'
    ;;
  *)
    echo "usage: session-routing.sh claude|codex" >&2
    exit 2
    ;;
esac
