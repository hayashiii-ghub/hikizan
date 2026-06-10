#!/usr/bin/env bash
# Emit a PreToolUse permission decision in Claude Code's official JSON form on
# stdout, then return. The caller exits 0 afterwards.
#
#   hz_decision deny "reason..."   -> block, reason relayed to the model
#   hz_decision ask  "reason..."   -> prompt the user to confirm
#   hz_decision allow "reason..."  -> explicit allow (rarely needed)
#
# Fallback: if jq is missing the hook could not have parsed its stdin either,
# so we degrade to the legacy stderr + exit-2 block to stay fail-safe.
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
