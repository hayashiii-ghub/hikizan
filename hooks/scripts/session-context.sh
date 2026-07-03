#!/usr/bin/env bash
# SessionStart(startup) hook. Prints hikizan routing / safety / the active tier
# to stdout, which Claude Code injects into the session context.
#
# Unlike the old bootstrap-claude-md.sh, this does NOT write to the host repo's
# CLAUDE.md. The conventions are therefore always the installed plugin version
# (no frozen copy to drift) and the user's repo is never silently mutated. Users
# who want a persistent file can run `/hikizan:init`.

set -uo pipefail
HERE="$(dirname "$0")"

# shellcheck source=lib/metrics.sh
source "$HERE/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }

JSON=$(cat 2>/dev/null || printf '{}')
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""' 2>/dev/null)

TIER="${HIKIZAN_TIER:-standard}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
TEMPLATE="$PLUGIN_ROOT/context/routing.md"
PREAMBLE="$PLUGIN_ROOT/context/standard-preamble.md"

if [ -n "$PLUGIN_ROOT" ] && [ -f "$TEMPLATE" ]; then
  cat "$TEMPLATE"
  # standard tier only: the scoped opt-out (procedures are optional, the exit
  # contract and the hook floors still bind). guided tier follows the skills
  # literally and never sees this.
  if [ "$TIER" = "standard" ] && [ -f "$PREAMBLE" ]; then
    printf '\n'
    cat "$PREAMBLE"
  fi
  printf '\nhikizan-tier (this session): %s\n' "$TIER"
  hikizan_metrics_log hook_fired session-context inject allow "$SESSION_ID"
else
  hikizan_metrics_log hook_fired session-context noop allow "$SESSION_ID"
fi

exit 0
