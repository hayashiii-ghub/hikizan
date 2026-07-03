#!/usr/bin/env bash
# Codex SessionStart hook: emit hikizan routing / tier / opt-out preamble as
# additionalContext (Codex injects it into the model context). Same template
# single-source as the CC session-context.sh; only the output envelope differs.
set -uo pipefail
HERE="$(dirname "$0")"
ROOT="$(cd "$HERE/../.." && pwd)"   # hikizan repo root (codex/scripts/ -> ../..)
TIER="${HIKIZAN_TIER:-standard}"
TEMPLATE="$ROOT/templates/CLAUDE.md"
PREAMBLE="$ROOT/templates/standard-preamble.md"
command -v jq >/dev/null 2>&1 || exit 0
[ -f "$TEMPLATE" ] || exit 0
CTX="$(cat "$TEMPLATE")"
if [ "$TIER" = "standard" ] && [ -f "$PREAMBLE" ]; then
  CTX="$CTX
$(cat "$PREAMBLE")"
fi
CTX="$CTX
hikizan-tier (this session): $TIER"
jq -nc --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
exit 0
