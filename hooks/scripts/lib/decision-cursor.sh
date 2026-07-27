#!/usr/bin/env bash
# Cursor hookの権限判断を、要求されるJSON形式で標準出力へ返す。
# 共通の判定結果をCursor固有の応答形式へ変換するために使う。
hz_cursor_decision() {
  local permission="$1" reason="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg p "$permission" --arg r "$reason" \
      '{permission:$p, user_message:$r, agent_message:$r}'
  else
    printf '%s\n' "$reason" >&2
    # defense-in-depth only: lib/guard.sh hz_require_jq already fails closed
    # before before-shell.sh gets this far, so this normally never executes.
    exit 2   # Cursor treats exit 2 as a block
  fi
}
