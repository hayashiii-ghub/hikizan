#!/usr/bin/env bash
# scripts/visual-contract.mdの視覚検証規則をjikkouとsadokuへ反映する。
# Shimonの実行条件と確認方法を、実装とレビューで揃えるために使う。
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts/visual-contract.md"
START='<!-- hikizan:visual:start -->'
END='<!-- hikizan:visual:end -->'
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

inject() { # <file>
  local file="$1" starts ends
  starts=$(grep -cF "$START" "$file")
  ends=$(grep -cF "$END" "$file")
  if [ "$starts" != "1" ] || [ "$ends" != "1" ]; then
    echo "✘ $file: expected exactly one visual block (start=$starts end=$ends)" >&2
    return 1
  fi
  awk -v s="$START" -v e="$END" -v src="$SRC" '
    $0==s { print; while ((getline line < src) > 0) print line; close(src); skip=1; next }
    $0==e { print; skip=0; next }
    !skip { print }
  ' "$file"
}

rc=0
for skill in jikkou sadoku; do
  file="$ROOT/skills/$skill/SKILL.md"
  new="$(inject "$file")" || { rc=1; continue; }
  if [ "$CHECK" -eq 1 ]; then
    if diff -q "$file" <(printf '%s\n' "$new") >/dev/null; then
      echo "✔ skills/$skill/SKILL.md visual block up to date"
    else
      echo "✘ skills/$skill/SKILL.md visual block is stale — run: bash scripts/gen-visual-contract.sh" >&2
      rc=1
    fi
  else
    printf '%s\n' "$new" > "$file"
    echo "✔ wrote skills/$skill/SKILL.md visual block"
  fi
done
exit "$rc"
