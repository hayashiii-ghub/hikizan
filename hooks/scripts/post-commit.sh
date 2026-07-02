#!/usr/bin/env bash
# PostToolUse hook for `git commit*`.
# Warns (stderr, exit 0) if the parent commit moved a submodule pointer
# while the submodule itself has unpushed commits. Cannot block because
# the commit is already done.

set -uo pipefail

# shellcheck source=lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }

JSON=$(cat)
CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""' 2>/dev/null)
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""' 2>/dev/null)

[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

# Bail if no submodules configured
[ ! -f .gitmodules ] && exit 0

# -z (NUL-terminated, "key\nvalue\0" per entry) is required here: a plain
# `awk '{print $2}'`/space-split takes only the first word of the value, and
# `cut -d' ' -f2-` still breaks because the submodule *name* embedded in the
# key defaults to the path, so a spaced path makes the key itself ambiguous
# on spaces too. -z keeps key and value unambiguous regardless of spaces.
SUBMODULE_PATHS=$(git config -z --file .gitmodules --get-regexp 'submodule\..*\.path' 2>/dev/null | tr '\0' '\n' | awk 'NR % 2 == 0')
[ -z "$SUBMODULE_PATHS" ] && exit 0

# Files touched by the last commit
LAST_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || true)
[ -z "$LAST_FILES" ] && exit 0

WARNED=0
# One path per line (paths may contain spaces), so read line-by-line instead
# of word-splitting on $SUBMODULE_PATHS.
while IFS= read -r SM; do
  [ -z "$SM" ] && continue
  # Match submodule path exactly as a touched entry
  if printf '%s\n' "$LAST_FILES" | grep -qFx "$SM"; then
    [ -d "$SM" ] || continue
    UNPUSHED=$(git -C "$SM" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$UNPUSHED" -gt 0 ] 2>/dev/null; then
      printf 'warning: submodule %s has %s unpushed commit(s) but parent already updated its pointer.\n' "$SM" "$UNPUSHED" >&2
      WARNED=1
    fi
  fi
done <<EOF
$SUBMODULE_PATHS
EOF

if [ "$WARNED" -eq 1 ]; then
  hikizan_metrics_log hook_fired post-commit submodule_unpushed warn "$SESSION_ID"
  printf 'push the submodule first, then re-push the parent.\n' >&2
fi
exit 0
