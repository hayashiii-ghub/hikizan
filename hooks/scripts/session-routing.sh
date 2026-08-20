#!/usr/bin/env bash
# セッション開始時に、短いスキル選択規則と現在のGit状態を渡す。
# 正しいリポジトリ状況と必要なスキルをモデルが最初に判断するために使う。

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROUTING="$ROOT/hooks/routing.md"
HARNESS="${1:-}"
INPUT=$(cat 2>/dev/null || true)
CWD=""
if command -v jq >/dev/null 2>&1 && [ -n "$INPUT" ]; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
[ -n "$CWD" ] || CWD="$PWD"

repo_status() {
  local root branch worktree upstream remote freshness="未確認" counts ahead behind fetch_pid fetch_ticks
  git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  root=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || return 0
  branch=$(git -C "$root" branch --show-current 2>/dev/null)
  [ -n "$branch" ] || branch="detached"
  if [ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]; then
    worktree="変更あり"
  else
    worktree="clean"
  fi
  upstream=$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
  if [ -z "$upstream" ]; then
    printf 'リポジトリ: %s / branch=%s / worktree=%s / upstream=なし' "$(basename "$root")" "$branch" "$worktree"
    return 0
  fi

  remote=$(git -C "$root" config "branch.$branch.remote" 2>/dev/null || true)
  if [ -n "$remote" ] && [ "${HIKIZAN_SKIP_FETCH:-0}" != "1" ]; then
    GIT_TERMINAL_PROMPT=0 git -C "$root" fetch --quiet --no-tags "$remote" </dev/null >/dev/null 2>&1 &
    fetch_pid=$!
    fetch_ticks=0
    while kill -0 "$fetch_pid" 2>/dev/null && [ "$fetch_ticks" -lt 20 ]; do
      sleep 0.1
      fetch_ticks=$((fetch_ticks + 1))
    done
    if kill -0 "$fetch_pid" 2>/dev/null; then
      kill "$fetch_pid" 2>/dev/null || true
      wait "$fetch_pid" 2>/dev/null || true
    elif wait "$fetch_pid" 2>/dev/null; then
      freshness="確認済み"
    fi
  elif [ "${HIKIZAN_SKIP_FETCH:-0}" = "1" ]; then
    freshness="省略"
  fi

  counts=$(git -C "$root" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null || true)
  ahead=$(printf '%s' "$counts" | awk '{print $1}')
  behind=$(printf '%s' "$counts" | awk '{print $2}')
  [ -n "$ahead" ] || ahead="?"
  [ -n "$behind" ] || behind="?"
  printf 'リポジトリ: %s / branch=%s / worktree=%s / upstream=%s / ahead=%s / behind=%s / remote=%s' \
    "$(basename "$root")" "$branch" "$worktree" "$upstream" "$ahead" "$behind" "$freshness"
}

STATUS=$(repo_status)
CONTEXT=""
if [ -f "$ROUTING" ]; then
  CONTEXT=$(cat "$ROUTING")
fi
if [ -n "$STATUS" ]; then
  CONTEXT="${CONTEXT}${CONTEXT:+

}## 作業開始時の状態

$STATUS"
fi

cursor_context="$STATUS"

case "$HARNESS" in
  claude)
    printf '%s\n' "$CONTEXT"
    ;;
  codex)
    command -v jq >/dev/null 2>&1 || exit 0
    jq -nc --arg context "$CONTEXT" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$context}}'
    ;;
  cursor)
    command -v jq >/dev/null 2>&1 || exit 0
    jq -nc --arg context "$cursor_context" '{additional_context:$context}'
    ;;
  pi|plain)
    printf '%s\n' "$CONTEXT"
    ;;
  *)
    echo "usage: session-routing.sh claude|codex|cursor|pi|plain" >&2
    exit 2
    ;;
esac
