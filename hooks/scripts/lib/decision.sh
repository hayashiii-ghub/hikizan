#!/usr/bin/env bash
# Claude CodeのPreToolUse判断を、要求されるJSON形式で標準出力へ返す。
# 共通の判定結果をClaude Code固有の応答形式へ変換するために使う。
hz_decision() {
  local decision="$1" reason="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg d "$decision" --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  else
    printf '%s\n' "$reason" >&2
    exit 2
  fi
}
