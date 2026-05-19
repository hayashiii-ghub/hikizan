#!/usr/bin/env bash
# PreToolUse hook for `gh pr create*`.
# Blocks (exit 2) if neither --draft nor --reviewer is specified.

set -uo pipefail

JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')

case "$COMMAND" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

HAS_DRAFT=0
HAS_REVIEWER=0

case "$COMMAND" in
  *"--draft"*) HAS_DRAFT=1 ;;
esac

case "$COMMAND" in
  *"--reviewer"*|*"-r "*) HAS_REVIEWER=1 ;;
esac

if [ "$HAS_DRAFT" -eq 0 ] && [ "$HAS_REVIEWER" -eq 0 ]; then
  cat >&2 <<EOF
gh pr create called without --draft and without --reviewer.

policy: non-draft PRs should specify at least one reviewer. options:
  1. add --draft (start as draft, request review later)
  2. add --reviewer @user (or comma-separated list)
  3. confirm intentional and re-run with explicit acknowledgement

hook will not auto-decide.
EOF
  exit 2
fi

exit 0
