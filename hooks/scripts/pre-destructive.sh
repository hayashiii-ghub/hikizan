#!/usr/bin/env bash
# PreToolUse hook for irreversible Bash commands (rm -rf, git reset --hard,
# git clean -f, git checkout discard). Claude Code / Cursor ask for explicit
# confirmation. Harnesses without an interactive `ask` decision invoke this
# entry point with `deny [harness name]`. Classification lives in
# lib/destructive.sh (unit-tested).

set -uo pipefail
HERE="$(dirname "$0")"
DECISION="ask"
GUIDANCE="this is irreversible. confirm it is intended before running — hikizan does not
auto-approve destructive operations."
if [ "${1:-}" = "deny" ]; then
  HARNESS="${2:-Codex}"
  DECISION="deny"
  GUIDANCE="this is irreversible. $HARNESS hooks cannot request approval, so hikizan blocked it.
if it is intended, ask the user to run it manually outside $HARNESS; do not retry
through another tool or shell path."
fi

# shellcheck source=lib/destructive.sh
source "$HERE/lib/destructive.sh"
# shellcheck source=lib/decision.sh
source "$HERE/lib/decision.sh"
# shellcheck source=lib/guard.sh
source "$HERE/lib/guard.sh"

hz_require_jq
JSON=$(cat)
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""')

LABEL=$(hz_destructive_label "$COMMAND")
if [ -n "$LABEL" ]; then
  hz_decision "$DECISION" "destructive operation detected: $LABEL

$GUIDANCE"
  exit 0
fi

exit 0
