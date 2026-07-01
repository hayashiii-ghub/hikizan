#!/usr/bin/env bash
# Consistency lint for hikizan skills.
#
#   1. The 共通ルール block (between the contract markers) must be byte-identical
#      across every skills/*/SKILL.md. It is inlined per skill (not a shared
#      file) so `npx skills add` per-skill copies keep it; this lint is what
#      keeps the copies from drifting.
#   2. Each SKILL.md must carry exactly one contract block.
#
# Exit 0 iff everything is consistent. Run: bash scripts/check-consistency.sh

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
START='<!-- hikizan:contract:start -->'
END='<!-- hikizan:contract:end -->'

extract() { awk -v s="$START" -v e="$END" '$0==s{f=1;next} $0==e{f=0} f' "$1"; }

# Core workflow skills carry the shared contract. Utility skills (e.g. init)
# are exempt — they have no contract block.
CORE="sekkei jikkou tansaku sadoku shiken teishutsu kaku"

fail=0
ref=""
ref_file=""
count=0

for f in "$ROOT"/skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  name="$(basename "$(dirname "$f")")"
  case " $CORE " in *" $name "*) ;; *) continue ;; esac
  count=$((count + 1))

  # exactly one contract block
  starts=$(grep -cF "$START" "$f")
  ends=$(grep -cF "$END" "$f")
  if [ "$starts" != "1" ] || [ "$ends" != "1" ]; then
    echo "✘ $name: expected exactly one contract block (start=$starts end=$ends)"
    fail=1
    continue
  fi

  blk="$(extract "$f")"
  if [ -z "$ref" ]; then
    ref="$blk"; ref_file="$name"
  elif [ "$blk" != "$ref" ]; then
    echo "✘ $name: 共通ルール block differs from $ref_file"
    diff <(printf '%s\n' "$ref") <(printf '%s\n' "$blk") | sed 's/^/    /' | head -20
    fail=1
  fi
done

if [ "$count" -eq 0 ]; then
  echo "✘ no skills found under $ROOT/skills"
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "✔ 共通ルール block identical across $count skills (ref: $ref_file)"
fi

# 3. plugin agents/ (first-class subagents) must match the per-skill fallback
#    copies under skills/sadoku/references/agents/ byte-for-byte.
for a in "$ROOT"/agents/*.md; do
  [ -e "$a" ] || continue
  base="$(basename "$a")"
  fb="$ROOT/skills/sadoku/references/agents/$base"
  if [ ! -f "$fb" ]; then
    echo "✘ agents/$base has no fallback at skills/sadoku/references/agents/$base"
    fail=1
  elif ! diff -q "$a" "$fb" >/dev/null; then
    echo "✘ agents/$base differs from its fallback copy"
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "✔ agents/ match references/agents/ fallback copies"

exit "$fail"
