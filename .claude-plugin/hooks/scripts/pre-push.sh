#!/usr/bin/env bash
# PreToolUse hook for `git push*`.
# Blocks (exit 2) on: (a) non-fast-forward, (b) force push to a protected branch.
# Stderr carries the user-facing options; CC relays it to Claude as an error.

set -uo pipefail

# shellcheck source=lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }

JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""')
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""')

[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

# Skip if not actually a git push (defensive — the `if` filter should already handle this)
case "$COMMAND" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

BRANCH=$(git branch --show-current 2>/dev/null || true)
[ -z "$BRANCH" ] && exit 0

# (a) non-fast-forward check
git fetch --quiet 2>/dev/null || true
UPSTREAM="origin/$BRANCH"
if git rev-parse --verify "$UPSTREAM" >/dev/null 2>&1; then
  BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || printf '0')
  if [ "$BEHIND" -gt 0 ] 2>/dev/null; then
    hikizan_metrics_log hook_fired pre-push nff block "$SESSION_ID"
    cat >&2 <<EOF
non-fast-forward push detected on branch '$BRANCH'.

local is $BEHIND commit(s) behind $UPSTREAM. options:
  1. git pull --rebase origin $BRANCH  (then push)
  2. push to a new branch instead
  3. abort

hook will not auto-decide. confirm explicitly in your next message.
EOF
    exit 2
  fi
fi

# (b) force push to protected branch
case "$COMMAND" in
  *"--force"*|*"--force-with-lease"*|*" -f "*|*" -f"|*"-f "*)
    PROTECTED='^(main|master|develop)$'
    # Extract target ref from `git push <remote> <ref>` form
    TARGET=$(printf '%s' "$COMMAND" | awk '
      /git push/ {
        for (i=1; i<=NF; i++) {
          if ($i == "push") {
            # skip remote name (next non-flag arg), then capture ref
            j = i + 1
            while (j <= NF && substr($j, 1, 1) == "-") j++
            if (j <= NF) { j++ }
            while (j <= NF && substr($j, 1, 1) == "-") j++
            if (j <= NF) print $j
            exit
          }
        }
      }')
    if printf '%s' "${TARGET:-}" | grep -qE "$PROTECTED"; then
      hikizan_metrics_log hook_fired pre-push force_protected block "$SESSION_ID"
      cat >&2 <<EOF
force push targeting protected branch '$TARGET'.

protected branches: main / master / develop. policy: require explicit
user confirmation. abort and ask the user before re-running.
EOF
      exit 2
    fi
    ;;
esac

hikizan_metrics_log hook_fired pre-push none allow "$SESSION_ID"
exit 0
