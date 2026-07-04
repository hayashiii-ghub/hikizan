#!/usr/bin/env bash
# Stamp the first-class subagent definitions under agents/ from
# skills/sadoku/references/agents/ (the SoT — that copy is what per-skill
# distribution channels receive, so it must never dangle). agents/ is what
# Claude Code and Cursor auto-discover; the stamped copies are committed.
# Do not edit agents/*.md by hand — edit the source and rerun.
#   bash scripts/gen-agents.sh           # write the copies
#   bash scripts/gen-agents.sh --check   # fail if regen would change them
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRCDIR="$ROOT/skills/sadoku/references/agents"
OUTDIR="$ROOT/agents"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

rc=0
found=0
for src in "$SRCDIR"/*.md; do
  [ -e "$src" ] || continue
  found=1
  base="$(basename "$src")"
  out="$OUTDIR/$base"
  if [ "$CHECK" -eq 1 ]; then
    if [ -f "$out" ] && diff -q "$src" "$out" >/dev/null; then
      echo "✔ agents/$base up to date"
    else
      echo "✘ agents/$base is stale — run: bash scripts/gen-agents.sh" >&2
      rc=1
    fi
  else
    mkdir -p "$OUTDIR"
    cp "$src" "$out"
    echo "✔ wrote agents/$base"
  fi
done
[ "$found" -eq 1 ] || { echo "✘ no sources under skills/sadoku/references/agents/" >&2; exit 1; }

# agents/ must not carry files that have no source counterpart (a renamed or
# removed subagent whose stale copy lingers would keep being auto-discovered).
for out in "$OUTDIR"/*.md; do
  [ -e "$out" ] || continue
  base="$(basename "$out")"
  if [ ! -f "$SRCDIR/$base" ]; then
    echo "✘ agents/$base has no source at skills/sadoku/references/agents/$base — remove it or add the source" >&2
    rc=1
  fi
done
exit "$rc"
