#!/usr/bin/env bash
# Claude CodeとCodexの起動時コンテキストへ、生成済みの短いスキル選択規則を渡す。

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROUTING="$ROOT/hooks/routing.md"
HARNESS="${1:-}"

[ -f "$ROUTING" ] || exit 0

case "$HARNESS" in
  claude)
    cat "$ROUTING"
    ;;
  codex)
    command -v jq >/dev/null 2>&1 || exit 0
    jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}' < "$ROUTING"
    ;;
  *)
    echo "usage: session-routing.sh claude|codex" >&2
    exit 2
    ;;
esac
