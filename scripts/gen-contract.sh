#!/usr/bin/env bash
# Stamp the 共通ルール block from scripts/contract.md (the SoT) into the
# contract marker region of every core skill's SKILL.md. The stamped copies
# are committed so every skill in the hikizan pack receives the same contract;
# this script replaces the hand-copy + byte-identity lint that used to keep the
# copies in sync. Cross-skill details are referenced by logical skill name, and
# the pack is installed as a unit.
#
#   bash scripts/gen-contract.sh           # write the blocks
#   bash scripts/gen-contract.sh --check   # fail if regen would change them
#
# Marker region in each skills/<name>/SKILL.md:
#   <!-- hikizan:contract:start -->
#   ...stamped from scripts/contract.md...
#   <!-- hikizan:contract:end -->

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts/contract.md"
CORE="$(jq -r '.core | join(" ")' "$ROOT/scripts/skills.json")"
[ -n "$CORE" ] || { echo "✘ failed to read core skills from scripts/skills.json" >&2; exit 1; }
[ -f "$SRC" ] || { echo "✘ missing $SRC" >&2; exit 1; }
START='<!-- hikizan:contract:start -->'
END='<!-- hikizan:contract:end -->'

inject() { # <file> — print <file> with the marker region content replaced by SRC
  local file="$1" starts ends
  starts=$(grep -cF "$START" "$file")
  ends=$(grep -cF "$END" "$file")
  if [ "$starts" != "1" ] || [ "$ends" != "1" ]; then
    echo "✘ $file: expected exactly one contract block (start=$starts end=$ends)" >&2
    return 1
  fi
  awk -v s="$START" -v e="$END" -v src="$SRC" '
    $0==s { print; while ((getline line < src) > 0) print line; close(src); skip=1; next }
    $0==e { print; skip=0; next }
    !skip { print }
  ' "$file"
}

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

rc=0
for s in $CORE; do
  file="$ROOT/skills/$s/SKILL.md"
  [ -f "$file" ] || { echo "✘ missing skills/$s/SKILL.md" >&2; rc=1; continue; }
  new="$(inject "$file")" || { rc=1; continue; }
  if [ "$CHECK" -eq 1 ]; then
    if ! diff -q "$file" <(printf '%s\n' "$new") >/dev/null; then
      echo "✘ skills/$s/SKILL.md contract block is stale — run: bash scripts/gen-contract.sh" >&2
      rc=1
    else
      echo "✔ skills/$s/SKILL.md contract block up to date"
    fi
  else
    printf '%s\n' "$new" > "$file"
    echo "✔ wrote skills/$s/SKILL.md"
  fi
done
exit "$rc"
