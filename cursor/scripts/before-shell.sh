#!/usr/bin/env bash
# Cursor `beforeShellExecution` hook — the floors port for harnesses that have
# no Claude Code hooks. Reuses the SAME unit-tested pure logic as the CC hooks
# (push-parse.sh, destructive.sh, pr-create.sh): destructive ops -> ask, force
# push to a protected branch -> deny, non-draft PR without reviewer -> deny.
#
# Cursor input is top-level {command, cwd, conversation_id, ...}; output is the
# Cursor permission JSON via lib/decision-cursor.sh. Absence of output = allow.
#
# Install: point ~/.cursor/hooks.json (or <project>/.cursor/hooks.json) at this
# script's absolute path. See cursor/README.md.

set -uo pipefail
LIB="$(cd "$(dirname "$0")/../../hooks/scripts/lib" && pwd)"
# shellcheck source=../../hooks/scripts/lib/push-parse.sh
source "$LIB/push-parse.sh"
# shellcheck source=../../hooks/scripts/lib/destructive.sh
source "$LIB/destructive.sh"
# shellcheck source=../../hooks/scripts/lib/pr-create.sh
source "$LIB/pr-create.sh"
# shellcheck source=../../hooks/scripts/lib/decision-cursor.sh
source "$LIB/decision-cursor.sh"
# shellcheck source=../../hooks/scripts/lib/guard.sh
source "$LIB/guard.sh"

hz_require_jq
JSON=$(cat)
CMD=$(printf '%s' "$JSON" | jq -r '.command // ""')
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

# 1. irreversible op -> ask for confirmation
LABEL=$(hz_destructive_label "$CMD")
if [ -n "$LABEL" ]; then
  hz_cursor_decision ask "destructive operation detected: $LABEL

this is irreversible. confirm it is intended before running."
  exit 0
fi

# 2. force-equivalent push to a protected branch -> deny. Check the top-level
# command and executable command substitutions with the same classifier.
hz_cursor_check_push() {
  local command="$1" pushdir branch hit
  [ "$(hz_git_subcommand "$command")" = "push" ] || return 0
  hikizan_push_is_forceful "$command" || return 0

  if ! hz_push_context_supported "$command"; then
    hz_cursor_decision deny "force-equivalent push uses options that prevent the hook from resolving the git repository context exactly.

policy: fail closed because the current branch may be protected. abort and ask
the user. if confirmed, run the command manually outside the guarded agent."
    exit 0
  fi

  pushdir=$(hz_push_dir "$command")
  [ -n "$pushdir" ] && [ ! -d "$pushdir" ] && pushdir=""
  if [ -n "$pushdir" ]; then branch=$(git -C "$pushdir" branch --show-current 2>/dev/null || true)
  else branch=$(git branch --show-current 2>/dev/null || true); fi
  hit=$(hikizan_push_protected_hit "$command" "$branch") || hit=""
  if [ -n "$hit" ]; then
    hz_cursor_decision deny "force-equivalent push (force / +refspec / delete / mirror / all) targeting protected branch '$hit'.

protected: main / master / develop. this deny has no agent-side override.
if confirmed, the user must run the command manually outside the guarded agent."
    exit 0
  fi
}

hz_collect_command_segments "$CMD"
COMMAND_SEGMENT_INDEX=0
while [ "$COMMAND_SEGMENT_INDEX" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
  COMMAND_SEGMENT="${HZ_COMMAND_SEGMENTS[$COMMAND_SEGMENT_INDEX]}"
  hz_cursor_check_push "$COMMAND_SEGMENT"
  COMMAND_SEGMENT_INDEX=$((COMMAND_SEGMENT_INDEX + 1))
done

hz_collect_nested_commands "$CMD"
NESTED_COMMAND_COUNT="$HZ_NESTED_COUNT"
NESTED_COMMAND_INDEX=0
while [ "$NESTED_COMMAND_INDEX" -lt "$NESTED_COMMAND_COUNT" ]; do
  NESTED_COMMAND="${HZ_NESTED_COMMANDS[$NESTED_COMMAND_INDEX]}"
  hz_collect_command_segments "$NESTED_COMMAND"
  COMMAND_SEGMENT_INDEX=0
  while [ "$COMMAND_SEGMENT_INDEX" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
    COMMAND_SEGMENT="${HZ_COMMAND_SEGMENTS[$COMMAND_SEGMENT_INDEX]}"
    hz_cursor_check_push "$COMMAND_SEGMENT"
    COMMAND_SEGMENT_INDEX=$((COMMAND_SEGMENT_INDEX + 1))
  done
  NESTED_COMMAND_INDEX=$((NESTED_COMMAND_INDEX + 1))
done

# 3. non-draft PR without reviewer -> deny (workflow floor, CC の pre-pr-create と同条件)
if hz_prcreate_needs_review "$CMD"; then
  hz_cursor_decision deny "gh pr create called without --draft and without a reviewer.

policy: a non-draft PR should name at least one reviewer.
options: add --draft or --reviewer @user. otherwise the user must run the
command manually outside the guarded agent."
  exit 0
fi

exit 0
