#!/usr/bin/env bash
# PreToolUse hook for git push. Denies (a) non-fast-forward pushes and
# (b) force pushes to a protected branch. Target resolution lives in
# lib/push-parse.sh and is unit-tested (hooks/tests/) so the C3 bypasses
# (HEAD:main refspec, omitted ref, `git -C` prefix) stay closed.

set -uo pipefail
HERE="$(dirname "$0")"

# shellcheck source=lib/metrics.sh
source "$HERE/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }
# shellcheck source=lib/push-parse.sh
source "$HERE/lib/push-parse.sh"
# shellcheck source=lib/destructive.sh
source "$HERE/lib/destructive.sh"   # for hz_git_subcommand
# shellcheck source=lib/decision.sh
source "$HERE/lib/decision.sh"
# shellcheck source=lib/guard.sh
source "$HERE/lib/guard.sh"

hz_require_jq
JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""')
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""')

[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

# Check one executable command. The top-level command and every extracted
# command-substitution body pass through the same classifier.
HZ_PUSH_DIR=""
hz_git_in_push_dir() {
  if [ -n "$HZ_PUSH_DIR" ]; then
    git -C "$HZ_PUSH_DIR" "$@"
  else
    git "$@"
  fi
}

hz_check_push_command() {
  local command="$1" branch hit remote upstream behind remote_shell branch_shell
  [ "$(hz_git_subcommand "$command")" = "push" ] || return 0

  if hikizan_push_is_forceful "$command" && ! hz_push_context_supported "$command"; then
    hikizan_metrics_log hook_fired pre-push force_protected block "$SESSION_ID"
    hz_decision deny "force-equivalent push uses options for which the hook cannot resolve git repository context exactly (multiple -C, --git-dir, --work-tree, --namespace, --bare, or GIT_DIR/GIT_WORK_TREE/GIT_NAMESPACE).

policy: fail closed because the current branch may be protected. abort and ask
the user. if confirmed, the user must run the command manually outside the
guarded agent; do not rewrite or retry it to bypass this floor."
    exit 0
  fi

  # Resolve the repo the push targets (one -C <dir> is supported).
  HZ_PUSH_DIR=$(hz_push_dir "$command")
  [ -n "$HZ_PUSH_DIR" ] && [ ! -d "$HZ_PUSH_DIR" ] && HZ_PUSH_DIR=""

  branch=$(hz_git_in_push_dir branch --show-current 2>/dev/null || true)

  # Force-equivalent push to a protected branch — cheap, no network, first.
  if hikizan_push_is_forceful "$command"; then
    hit=$(hikizan_push_protected_hit "$command" "$branch") || hit=""
    if [ -n "$hit" ]; then
      hikizan_metrics_log hook_fired pre-push force_protected block "$SESSION_ID"
      hz_decision deny "force-equivalent push (force / +refspec / delete / mirror / all) targeting protected branch '$hit'.

protected branches: main / master / develop. policy: require explicit user
confirmation. this deny has no agent-side override: abort and ask the user.
if confirmed, the user must run the command manually outside the guarded agent."
      exit 0
    fi
  fi

  # Non-fast-forward needs an upstream, so it follows the cheap force path.
  [ -z "$branch" ] && return 0
  remote=$(hikizan_push_remote "$command")
  [ -z "$remote" ] && remote=$(hz_git_in_push_dir config "branch.$branch.remote" 2>/dev/null || true)
  [ -z "$remote" ] && remote=origin
  hz_git_in_push_dir fetch --quiet "$remote" 2>/dev/null || true
  upstream="$remote/$branch"
  if hz_git_in_push_dir rev-parse --verify "$upstream" >/dev/null 2>&1; then
    behind=$(hz_git_in_push_dir rev-list --count "HEAD..$upstream" 2>/dev/null || printf '0')
    if [ "$behind" -gt 0 ] 2>/dev/null; then
      printf -v remote_shell '%q' "$remote"
      printf -v branch_shell '%q' "$branch"
      hikizan_metrics_log hook_fired pre-push nff block "$SESSION_ID"
      hz_decision deny "non-fast-forward push on branch '$branch': local is $behind commit(s) behind $upstream.

options: 1) git pull --rebase $remote_shell $branch_shell then push  2) push to a new branch  3) abort.
hook will not auto-decide; confirm explicitly in your next message."
      exit 0
    fi
  fi
}

hz_collect_command_segments "$COMMAND"
COMMAND_SEGMENT_INDEX=0
while [ "$COMMAND_SEGMENT_INDEX" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
  COMMAND_SEGMENT="${HZ_COMMAND_SEGMENTS[$COMMAND_SEGMENT_INDEX]}"
  hz_check_push_command "$COMMAND_SEGMENT"
  COMMAND_SEGMENT_INDEX=$((COMMAND_SEGMENT_INDEX + 1))
done

hz_collect_nested_commands "$COMMAND"
NESTED_COMMAND_COUNT="$HZ_NESTED_COUNT"
NESTED_COMMAND_INDEX=0
while [ "$NESTED_COMMAND_INDEX" -lt "$NESTED_COMMAND_COUNT" ]; do
  NESTED_COMMAND="${HZ_NESTED_COMMANDS[$NESTED_COMMAND_INDEX]}"
  hz_collect_command_segments "$NESTED_COMMAND"
  COMMAND_SEGMENT_INDEX=0
  while [ "$COMMAND_SEGMENT_INDEX" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
    COMMAND_SEGMENT="${HZ_COMMAND_SEGMENTS[$COMMAND_SEGMENT_INDEX]}"
    hz_check_push_command "$COMMAND_SEGMENT"
    COMMAND_SEGMENT_INDEX=$((COMMAND_SEGMENT_INDEX + 1))
  done
  NESTED_COMMAND_INDEX=$((NESTED_COMMAND_INDEX + 1))
done

hikizan_metrics_log hook_fired pre-push none allow "$SESSION_ID"
exit 0
