#!/usr/bin/env bash
# SessionStart hook: idempotently bootstrap "## hikizan Conventions" into
# the project's CLAUDE.md.
#
# Three cases:
#   (a) CLAUDE.md does not exist            -> create it from the template
#   (b) CLAUDE.md exists, no marker section -> append the template
#   (c) CLAUDE.md exists, marker present    -> no-op (idempotent)
#
# Marker: the literal heading "## hikizan Conventions" at the top of the
# template. grep -F prevents regex surprises.

set -uo pipefail

JSON=$(cat 2>/dev/null || printf '{}')
PROJECT_DIR=$(printf '%s' "$JSON" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$PROJECT_DIR" ] && PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
[ -z "$PROJECT_DIR" ] && exit 0
[ ! -d "$PROJECT_DIR" ] && exit 0

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && exit 0
TEMPLATE="$PLUGIN_ROOT/templates/CLAUDE.md"
[ ! -f "$TEMPLATE" ] && exit 0

TARGET="$PROJECT_DIR/CLAUDE.md"
MARKER="## hikizan Conventions"

if [ ! -f "$TARGET" ]; then
  cp "$TEMPLATE" "$TARGET"
  printf 'hikizan: created %s\n' "$TARGET" >&2
elif ! grep -qF "$MARKER" "$TARGET"; then
  {
    printf '\n\n'
    cat "$TEMPLATE"
  } >> "$TARGET"
  printf 'hikizan: appended Conventions section to %s\n' "$TARGET" >&2
fi
# else: marker already present, idempotent no-op

exit 0
