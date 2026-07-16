#!/usr/bin/env bash
# PreToolUse hook for irreversible Bash commands (rm -rf, git reset --hard,
# git clean -f, git checkout discard). Claude Code / Cursor ask for explicit
# confirmation. Codex invokes this entry point with `deny` because its
# PreToolUse contract does not support the `ask` decision. Classification
# lives in lib/destructive.sh (unit-tested).

set -uo pipefail
HERE="$(dirname "$0")"
DECISION="ask"
METRIC_DECISION="ask"
GUIDANCE="this is irreversible. confirm it is intended before running — hikizan does not
auto-approve destructive operations."
if [ "${1:-}" = "deny" ]; then
  DECISION="deny"
  METRIC_DECISION="block"
  GUIDANCE="this is irreversible. Codex hooks cannot request approval, so hikizan blocked it.
if it is intended, ask the user to run it manually outside Codex; do not retry
through another tool or shell path."
fi

# shellcheck source=lib/metrics.sh
source "$HERE/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }
# shellcheck source=lib/destructive.sh
source "$HERE/lib/destructive.sh"
# shellcheck source=lib/decision.sh
source "$HERE/lib/decision.sh"
# shellcheck source=lib/guard.sh
source "$HERE/lib/guard.sh"

hz_require_jq
JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""')

LABEL=$(hz_destructive_label "$COMMAND")
if [ -n "$LABEL" ]; then
  hikizan_metrics_log hook_fired pre-destructive destructive "$METRIC_DECISION" "$SESSION_ID"
  hz_decision "$DECISION" "destructive operation detected: $LABEL

$GUIDANCE"
  exit 0
fi

exit 0
