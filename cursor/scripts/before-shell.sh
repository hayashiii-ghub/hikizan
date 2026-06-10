#!/usr/bin/env bash
# Cursor `beforeShellExecution` hook — the floors port for harnesses that have
# no Claude Code hooks. Reuses the SAME unit-tested pure logic as the CC hooks
# (push-parse.sh, destructive.sh): destructive ops -> ask, force push to a
# protected branch -> deny.
#
# Cursor input is top-level {command, cwd, conversation_id, ...}; output is the
# Cursor permission JSON via lib/decision-cursor.sh. Absence of output = allow.
#
# Install: point ~/.cursor/hooks.json (or <project>/.cursor/hooks.json) at this
# script's absolute path. See docs/cursor-floors.md.

set -uo pipefail
LIB="$(cd "$(dirname "$0")/../../hooks/scripts/lib" && pwd)"
# shellcheck source=../../hooks/scripts/lib/push-parse.sh
source "$LIB/push-parse.sh"
# shellcheck source=../../hooks/scripts/lib/destructive.sh
source "$LIB/destructive.sh"
# shellcheck source=../../hooks/scripts/lib/decision-cursor.sh
source "$LIB/decision-cursor.sh"

JSON=$(cat)
CMD=$(printf '%s' "$JSON" | jq -r '.command // ""')
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

# 1. irreversible op -> ask for confirmation
LABEL=$(hz_destructive_label "$CMD")
if [ -n "$LABEL" ]; then
  hz_cursor_decision ask "destructive operation detected: $LABEL

this is irreversible. confirm it is intended before running."
  exit 0
fi

# 2. force push to a protected branch -> deny
case " $CMD " in *" push "*) IS_PUSH=1 ;; *) IS_PUSH=0 ;; esac
case "$CMD" in *git*) ;; *) IS_PUSH=0 ;; esac
if [ "$IS_PUSH" = "1" ] && hikizan_push_has_force "$CMD"; then
  PUSHDIR=$(hz_push_dir "$CMD")
  [ -n "$PUSHDIR" ] && [ ! -d "$PUSHDIR" ] && PUSHDIR=""
  if [ -n "$PUSHDIR" ]; then BRANCH=$(git -C "$PUSHDIR" branch --show-current 2>/dev/null || true)
  else BRANCH=$(git branch --show-current 2>/dev/null || true); fi
  PROTECTED='^(main|master|develop)$'
  HIT=""
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    if printf '%s' "$t" | grep -qE "$PROTECTED"; then HIT="$t"; break; fi
  done <<EOF
$(hikizan_push_targets "$CMD" "$BRANCH")
EOF
  if [ -n "$HIT" ]; then
    hz_cursor_decision deny "force push targeting protected branch '$HIT'.

protected: main / master / develop. confirm explicitly before re-running."
    exit 0
  fi
fi

exit 0
