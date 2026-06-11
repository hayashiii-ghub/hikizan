#!/usr/bin/env bash
# PreToolUse hook for `gh pr create`. Denies a non-draft PR that names no
# reviewer. Recognises both long and short flags (--draft/-d, --reviewer/-r).

set -uo pipefail
HERE="$(dirname "$0")"

# shellcheck source=lib/metrics.sh
source "$HERE/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }
# shellcheck source=lib/decision.sh
source "$HERE/lib/decision.sh"

JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""')

case "$COMMAND" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

HAS_DRAFT=0
HAS_REVIEWER=0
case " $COMMAND " in
  *" --draft "*|*" -d "*) HAS_DRAFT=1 ;;
esac
case " $COMMAND " in
  *" --reviewer "*|*" --reviewer="*|*" -r "*) HAS_REVIEWER=1 ;;
esac

if [ "$HAS_DRAFT" -eq 0 ] && [ "$HAS_REVIEWER" -eq 0 ]; then
  hikizan_metrics_log hook_fired pre-pr-create no_draft_no_reviewer block "$SESSION_ID"
  hz_decision deny "gh pr create called without --draft and without a reviewer.

policy: a non-draft PR should name at least one reviewer. options:
  1. add --draft (start as draft, request review later)
  2. add --reviewer @user (or a comma-separated list)
  3. confirm intentional and re-run with an explicit acknowledgement.
hook will not auto-decide."
  exit 0
fi

hikizan_metrics_log hook_fired pre-pr-create none allow "$SESSION_ID"
exit 0
