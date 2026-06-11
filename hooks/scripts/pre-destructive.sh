#!/usr/bin/env bash
# PreToolUse hook for irreversible Bash commands (rm -rf, git reset --hard,
# git clean -f, git checkout discard). Asks for explicit confirmation rather
# than denying — legitimate use stays possible, but nothing runs unattended.
# Classification lives in lib/destructive.sh (unit-tested).

set -uo pipefail
HERE="$(dirname "$0")"

# shellcheck source=lib/metrics.sh
source "$HERE/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }
# shellcheck source=lib/destructive.sh
source "$HERE/lib/destructive.sh"
# shellcheck source=lib/decision.sh
source "$HERE/lib/decision.sh"

JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""')

LABEL=$(hz_destructive_label "$COMMAND")
if [ -n "$LABEL" ]; then
  hikizan_metrics_log hook_fired pre-destructive destructive ask "$SESSION_ID"
  hz_decision ask "destructive operation detected: $LABEL

this is irreversible. confirm it is intended before running — hikizan does not
auto-approve destructive operations."
  exit 0
fi

exit 0
