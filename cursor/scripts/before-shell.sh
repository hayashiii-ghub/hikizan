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

# 2. force-equivalent push to a protected branch -> deny (anchored on the git
# subcommand so quoted strings and `git stash push` never trigger)
if [ "$(hz_git_subcommand "$CMD")" = "push" ] && hikizan_push_is_forceful "$CMD"; then
  PUSHDIR=$(hz_push_dir "$CMD")
  [ -n "$PUSHDIR" ] && [ ! -d "$PUSHDIR" ] && PUSHDIR=""
  if [ -n "$PUSHDIR" ]; then BRANCH=$(git -C "$PUSHDIR" branch --show-current 2>/dev/null || true)
  else BRANCH=$(git branch --show-current 2>/dev/null || true); fi
  HIT=$(hikizan_push_protected_hit "$CMD" "$BRANCH") || HIT=""
  if [ -n "$HIT" ]; then
    hz_cursor_decision deny "force-equivalent push (force / +refspec / delete / mirror / all) targeting protected branch '$HIT'.

protected: main / master / develop. this deny has no agent-side override.
if confirmed, the user must run the command manually outside the guarded agent."
    exit 0
  fi
fi

# 3. non-draft PR without reviewer -> deny (workflow floor, CC の pre-pr-create と同条件)
if hz_prcreate_needs_review "$CMD"; then
  hz_cursor_decision deny "gh pr create called without --draft and without a reviewer.

policy: a non-draft PR should name at least one reviewer.
options: add --draft or --reviewer @user. otherwise the user must run the
command manually outside the guarded agent."
  exit 0
fi

exit 0
