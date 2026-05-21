#!/usr/bin/env bash
# SessionStart hook: add "## hikizan Conventions" to the project's
# CLAUDE.md without duplicating it.
#
# Three cases:
#   (a) CLAUDE.md does not exist            -> create it from the template
#   (b) CLAUDE.md exists, no marker section -> append the template
#   (c) CLAUDE.md exists, marker present    -> no-op
#
# Marker: the literal heading "## hikizan Conventions" at the top of the
# template. grep -F prevents regex surprises.

set -uo pipefail

# shellcheck source=lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }

JSON=$(cat 2>/dev/null || printf '{}')
PROJECT_DIR=$(printf '%s' "$JSON" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$PROJECT_DIR" ] && PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
[ -z "$PROJECT_DIR" ] && exit 0
[ ! -d "$PROJECT_DIR" ] && exit 0
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""' 2>/dev/null)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && exit 0
TEMPLATE="$PLUGIN_ROOT/templates/CLAUDE.md"
[ ! -f "$TEMPLATE" ] && exit 0

TARGET="$PROJECT_DIR/CLAUDE.md"
MARKER="## hikizan Conventions"

if [ ! -f "$TARGET" ]; then
  cp "$TEMPLATE" "$TARGET"
  hikizan_metrics_log hook_fired bootstrap-claude-md create allow "$SESSION_ID"
  printf 'hikizan: created %s\n' "$TARGET" >&2
elif ! grep -qF "$MARKER" "$TARGET"; then
  {
    printf '\n\n'
    cat "$TEMPLATE"
  } >> "$TARGET"
  hikizan_metrics_log hook_fired bootstrap-claude-md append allow "$SESSION_ID"
  printf 'hikizan: appended Conventions section to %s\n' "$TARGET" >&2
else
  hikizan_metrics_log hook_fired bootstrap-claude-md noop allow "$SESSION_ID"
fi

exit 0
