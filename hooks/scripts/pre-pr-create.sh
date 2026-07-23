#!/usr/bin/env bash
# PreToolUse hook for `gh pr create`. Denies a non-draft PR that names no
# reviewer. Recognises both long and short flags (--draft/-d, --reviewer/-r).

set -uo pipefail
HERE="$(dirname "$0")"

# shellcheck source=lib/decision.sh
source "$HERE/lib/decision.sh"
# shellcheck source=lib/guard.sh
source "$HERE/lib/guard.sh"
# shellcheck source=lib/tokenize.sh
source "$HERE/lib/tokenize.sh"
# shellcheck source=lib/pr-create.sh
source "$HERE/lib/pr-create.sh"

hz_require_jq
JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')

hz_is_pr_create "$COMMAND" || exit 0

if hz_prcreate_needs_review "$COMMAND"; then
  hz_decision deny "gh pr create called without --draft and without a reviewer.

policy: a non-draft PR should name at least one reviewer. options:
  1. add --draft (start as draft, request review later)
  2. add --reviewer @user (or a comma-separated list)
this deny has no acknowledgement override. if neither option applies, the user
must run the command manually outside the guarded agent."
  exit 0
fi

exit 0
