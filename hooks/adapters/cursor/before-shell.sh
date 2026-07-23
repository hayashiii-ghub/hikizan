#!/usr/bin/env bash
# Cursor `beforeShellExecution` hook — the floors port for harnesses that have
# no Claude Code hooks. Reuses the SAME unit-tested pure logic as the CC hooks
# (push-parse.sh, destructive.sh, pr-create.sh): destructive ops -> ask, force
# push to a protected branch -> deny, non-draft PR without reviewer -> deny.
#
# Cursor input is top-level {command, cwd, conversation_id, ...}; output is the
# Cursor permission JSON via lib/decision-cursor.sh. Absence of output = allow.
#
# Cursor adapter for the shared safety-floor classifiers.

set -uo pipefail
LIB="$(cd "$(dirname "$0")/../../scripts/lib" && pwd)"
# shellcheck source=../../scripts/lib/push-parse.sh
source "$LIB/push-parse.sh"
# shellcheck source=../../scripts/lib/destructive.sh
source "$LIB/destructive.sh"
# shellcheck source=../../scripts/lib/pr-create.sh
source "$LIB/pr-create.sh"
# shellcheck source=../../scripts/lib/decision-cursor.sh
source "$LIB/decision-cursor.sh"
# shellcheck source=../../scripts/lib/guard.sh
source "$LIB/guard.sh"

hz_require_jq
JSON=$(cat)
CMD=$(printf '%s' "$JSON" | jq -r '.command // ""')
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

# Fail-closed classifications must run before any ask: Cursor accepts one
# decision, so an early ask would otherwise mask a later deny in the command.
if hz_command_has_unresolved_env_split "$CMD"; then
  hz_cursor_decision deny "env -S command contains an unresolved variable expansion, so the hook cannot identify which floor applies safely.

policy: fail closed. use an explicit command without indirect env -S expansion."
  exit 0
fi

# 1. force-equivalent push to a protected branch -> deny. Check the top-level
# command and executable command substitutions with the same classifier.
hz_cursor_check_push() {
  local command="$1" pushdir branch hit remote upstream behind remote_shell branch_shell
  [ "$(hz_git_subcommand "$command")" = "push" ] || return 0

  if [ "${HZ_PRIOR_CONTEXT_CHANGE:-0}" = 1 ]; then
    hz_cursor_decision deny "push follows cd/pushd in the same shell command, so the hook cannot reproduce repository context exactly.

policy: fail closed because protected-branch and non-fast-forward checks need
the exact repository. run the directory change and push as separate commands."
    exit 0
  fi

  if hikizan_push_is_forceful "$command" && ! hz_push_context_supported "$command"; then
    hz_cursor_decision deny "force-equivalent push uses options that prevent the hook from resolving the git repository context exactly.

policy: fail closed because the current branch may be protected. abort and ask
the user. if confirmed, run the command manually outside the guarded agent."
    exit 0
  fi

  pushdir=$(hz_push_dir "$command")
  [ -n "$pushdir" ] && [ ! -d "$pushdir" ] && pushdir=""
  if [ -n "$pushdir" ]; then branch=$(git -C "$pushdir" branch --show-current 2>/dev/null || true)
  else branch=$(git branch --show-current 2>/dev/null || true); fi
  if hikizan_push_is_forceful "$command"; then
    hit=$(hikizan_push_protected_hit "$command" "$branch") || hit=""
    if [ -n "$hit" ]; then
      hz_cursor_decision deny "force-equivalent push (force / +refspec / delete / mirror / all) targeting protected branch '$hit'.

protected: main / master / develop. this deny has no agent-side override.
if confirmed, the user must run the command manually outside the guarded agent."
      exit 0
    fi
  fi

  [ -z "$branch" ] && return 0
  remote=$(hikizan_push_remote "$command")
  if [ -z "$remote" ]; then
    if [ -n "$pushdir" ]; then remote=$(git -C "$pushdir" config "branch.$branch.remote" 2>/dev/null || true)
    else remote=$(git config "branch.$branch.remote" 2>/dev/null || true); fi
  fi
  [ -z "$remote" ] && remote=origin
  if [ -n "$pushdir" ]; then
    git -C "$pushdir" fetch --quiet "$remote" 2>/dev/null || true
    upstream="$remote/$branch"
    behind=$(git -C "$pushdir" rev-list --count "HEAD..$upstream" 2>/dev/null || printf '0')
  else
    git fetch --quiet "$remote" 2>/dev/null || true
    upstream="$remote/$branch"
    behind=$(git rev-list --count "HEAD..$upstream" 2>/dev/null || printf '0')
  fi
  if [ "$behind" -gt 0 ] 2>/dev/null; then
    printf -v remote_shell '%q' "$remote"
    printf -v branch_shell '%q' "$branch"
    hz_cursor_decision deny "non-fast-forward push on branch '$branch': local is $behind commit(s) behind $upstream.

options: git pull --rebase $remote_shell $branch_shell, push to a new branch, or abort."
    exit 0
  fi
}

hz_collect_command_segments "$CMD"
HZ_PRIOR_CONTEXT_CHANGE=0
COMMAND_SEGMENT_INDEX=0
while [ "$COMMAND_SEGMENT_INDEX" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
  COMMAND_SEGMENT="${HZ_COMMAND_SEGMENTS[$COMMAND_SEGMENT_INDEX]}"
  hz_cursor_check_push "$COMMAND_SEGMENT"
  case "$(hz_cmd_head "$COMMAND_SEGMENT")" in cd|pushd) HZ_PRIOR_CONTEXT_CHANGE=1 ;; esac
  COMMAND_SEGMENT_INDEX=$((COMMAND_SEGMENT_INDEX + 1))
done
HZ_TOP_CONTEXT_CHANGE="$HZ_PRIOR_CONTEXT_CHANGE"

hz_collect_nested_commands "$CMD"
NESTED_COMMAND_COUNT="$HZ_NESTED_COUNT"
NESTED_COMMAND_INDEX=0
while [ "$NESTED_COMMAND_INDEX" -lt "$NESTED_COMMAND_COUNT" ]; do
  NESTED_COMMAND="${HZ_NESTED_COMMANDS[$NESTED_COMMAND_INDEX]}"
  hz_collect_command_segments "$NESTED_COMMAND"
  HZ_PRIOR_CONTEXT_CHANGE="$HZ_TOP_CONTEXT_CHANGE"
  COMMAND_SEGMENT_INDEX=0
  while [ "$COMMAND_SEGMENT_INDEX" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
    COMMAND_SEGMENT="${HZ_COMMAND_SEGMENTS[$COMMAND_SEGMENT_INDEX]}"
    hz_cursor_check_push "$COMMAND_SEGMENT"
    case "$(hz_cmd_head "$COMMAND_SEGMENT")" in cd|pushd) HZ_PRIOR_CONTEXT_CHANGE=1 ;; esac
    COMMAND_SEGMENT_INDEX=$((COMMAND_SEGMENT_INDEX + 1))
  done
  NESTED_COMMAND_INDEX=$((NESTED_COMMAND_INDEX + 1))
done

# 2. non-draft PR without reviewer -> deny (workflow floor, CC の pre-pr-create と同条件)
if hz_prcreate_needs_review "$CMD"; then
  hz_cursor_decision deny "gh pr create called without --draft and without a reviewer.

policy: a non-draft PR should name at least one reviewer.
options: add --draft or --reviewer @user. otherwise the user must run the
command manually outside the guarded agent."
  exit 0
fi

# 3. deny floors are clear, so an irreversible op may now ask for confirmation.
LABEL=$(hz_destructive_label "$CMD")
if [ -n "$LABEL" ]; then
  hz_cursor_decision ask "destructive operation detected: $LABEL

this is irreversible. confirm it is intended before running."
  exit 0
fi

exit 0
