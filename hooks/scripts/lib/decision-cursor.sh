#!/usr/bin/env bash
# Emit a Cursor hook permission decision on stdout. Cursor's beforeShellExecution
# expects {"permission":"allow|deny|ask","user_message":...,"agent_message":...}.
# This is the Cursor-flavoured sibling of lib/decision.sh (which emits Claude
# Code's permissionDecision form) — same pure logic feeds both.
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
