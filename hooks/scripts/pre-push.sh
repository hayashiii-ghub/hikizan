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

# Defensive: only a real `git push` (head=git, subcommand=push). Anchoring on
# the subcommand keeps `git -C <dir> push` / `command git push` in scope while
# quoted strings (`git commit -m "force push"`) and `git stash push` stay out.
[ "$(hz_git_subcommand "$COMMAND")" = "push" ] || exit 0

# Resolve the repo the push targets (-C <dir> wins over cwd).
PUSHDIR=$(hz_push_dir "$COMMAND")
[ -n "$PUSHDIR" ] && [ ! -d "$PUSHDIR" ] && PUSHDIR=""
hz_git() { if [ -n "$PUSHDIR" ]; then git -C "$PUSHDIR" "$@"; else git "$@"; fi; }

BRANCH=$(hz_git branch --show-current 2>/dev/null || true)

# (b) force-equivalent push to a protected branch — cheap, no network, checked first.
if hikizan_push_is_forceful "$COMMAND"; then
  HIT=$(hikizan_push_protected_hit "$COMMAND" "$BRANCH") || HIT=""
  if [ -n "$HIT" ]; then
    hikizan_metrics_log hook_fired pre-push force_protected block "$SESSION_ID"
    hz_decision deny "force-equivalent push (force / +refspec / delete / mirror / all) targeting protected branch '$HIT'.

protected branches: main / master / develop. policy: require explicit user
confirmation. this deny has no agent-side override: abort and ask the user.
if confirmed, the user must run the command manually outside the guarded agent."
    exit 0
  fi
fi

# (a) non-fast-forward check — needs an upstream, so do it after the cheap path.
[ -z "$BRANCH" ] && { hikizan_metrics_log hook_fired pre-push none allow "$SESSION_ID"; exit 0; }
# Resolve the remote the push actually targets: explicit remote on the
# command line, then the branch's configured remote, then origin.
REMOTE=$(hikizan_push_remote "$COMMAND")
[ -z "$REMOTE" ] && REMOTE=$(hz_git config "branch.$BRANCH.remote" 2>/dev/null || true)
[ -z "$REMOTE" ] && REMOTE=origin
hz_git fetch --quiet "$REMOTE" 2>/dev/null || true
UPSTREAM="$REMOTE/$BRANCH"
if hz_git rev-parse --verify "$UPSTREAM" >/dev/null 2>&1; then
  BEHIND=$(hz_git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || printf '0')
  if [ "$BEHIND" -gt 0 ] 2>/dev/null; then
    hikizan_metrics_log hook_fired pre-push nff block "$SESSION_ID"
    hz_decision deny "non-fast-forward push on branch '$BRANCH': local is $BEHIND commit(s) behind $UPSTREAM.

options: 1) git pull --rebase $REMOTE $BRANCH then push  2) push to a new branch  3) abort.
hook will not auto-decide; confirm explicitly in your next message."
    exit 0
  fi
fi

hikizan_metrics_log hook_fired pre-push none allow "$SESSION_ID"
exit 0
