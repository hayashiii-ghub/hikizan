#!/usr/bin/env bash
# Entry guard for hook scripts. Without jq a hook cannot parse its stdin, so
# the PreToolUse floors would silently allow everything (fail-open). Fail
# closed instead: stderr + exit 2 blocks the tool call in both Claude Code
# and Cursor.
hz_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  printf 'hikizan hook: jq not found; failing closed rather than skipping safety checks. install jq to proceed.\n' >&2
  exit 2
}
