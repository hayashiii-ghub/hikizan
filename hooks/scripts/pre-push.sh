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

JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""')
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""')

[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

# Defensive: only a real `git push` (head=git, subcommand=push). Anchoring on
# the subcommand keeps `git -C <dir> push` / `command git push` in scope while
# quoted strings (`git commit -m "force push"`) and `git stash push` stay out.
[ "$(hz_git_subcommand "$COMMAND")" = "push" ] || exit 0

# Resolve the repo the push targets (-C <dir> wins over cwd).
PUSHDIR=$(hz_push_dir "$COMMAND")
[ -n "$PUSHDIR" ] && [ ! -d "$PUSHDIR" ] && PUSHDIR=""
hz_git() { if [ -n "$PUSHDIR" ]; then git -C "$PUSHDIR" "$@"; else git "$@"; fi; }

BRANCH=$(hz_git branch --show-current 2>/dev/null || true)

# (b) force push to a protected branch — cheap, no network, checked first.
if hikizan_push_has_force "$COMMAND"; then
  PROTECTED='^(main|master|develop)$'
  HIT=""
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    case "$t" in *[\*\?\[]*) HIT="$t (wildcard refspec could match a protected branch)"; break ;; esac
    if printf '%s' "$t" | grep -qE "$PROTECTED"; then HIT="$t"; break; fi
  done <<EOF
$(hikizan_push_targets "$COMMAND" "$BRANCH")
EOF
  if [ -n "$HIT" ]; then
    hikizan_metrics_log hook_fired pre-push force_protected block "$SESSION_ID"
    hz_decision deny "force push targeting protected branch '$HIT'.

protected branches: main / master / develop. policy: require explicit user
confirmation. abort and ask the user before re-running."
    exit 0
  fi
fi

# (a) non-fast-forward check — needs an upstream, so do it after the cheap path.
[ -z "$BRANCH" ] && { hikizan_metrics_log hook_fired pre-push none allow "$SESSION_ID"; exit 0; }
hz_git fetch --quiet 2>/dev/null || true
UPSTREAM="origin/$BRANCH"
if hz_git rev-parse --verify "$UPSTREAM" >/dev/null 2>&1; then
  BEHIND=$(hz_git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || printf '0')
  if [ "$BEHIND" -gt 0 ] 2>/dev/null; then
    hikizan_metrics_log hook_fired pre-push nff block "$SESSION_ID"
    hz_decision deny "non-fast-forward push on branch '$BRANCH': local is $BEHIND commit(s) behind $UPSTREAM.

options: 1) git pull --rebase origin $BRANCH then push  2) push to a new branch  3) abort.
hook will not auto-decide; confirm explicitly in your next message."
    exit 0
  fi
fi

hikizan_metrics_log hook_fired pre-push none allow "$SESSION_ID"
exit 0
