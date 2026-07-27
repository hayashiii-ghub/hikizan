#!/usr/bin/env bash
# 各SKILL.mdのdescriptionから、READMEのスキル起動条件表を生成する。
# スキル本文と人向け一覧の説明がずれないようにするために使う。

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORDER="$(jq -r '.core | join(" ")' "$ROOT/scripts/skills.json")"
[ -n "$ORDER" ] || { echo "✘ failed to read core skills from scripts/skills.json" >&2; exit 1; }
START='<!-- hikizan:triggers:start -->'
END='<!-- hikizan:triggers:end -->'

fm_field() { # <file> <field> -> frontmatter value with quotes stripped
  awk -v fld="$2" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm && $0 ~ "^"fld":" {
      sub("^"fld":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit
    }' "$1"
}

gen_table() {
  printf '%s\n' "$START"
  printf '<!-- scripts/gen-trigger-docs.shがskills/*/SKILL.mdの`frontmatter`から生成。手動編集しない -->\n\n'
  printf '| スキル | 起動トリガー |\n|---|---|\n'
  for s in $ORDER; do
    f="$ROOT/skills/$s/SKILL.md"
    [ -f "$f" ] || continue
    description="$(fm_field "$f" description)"
    printf '| `%s` | %s |\n' "$s" "$description"
  done
  printf '\n発動条件の正本は各`SKILL.md`の`frontmatter`にある`description`です。\n'
  printf '%s\n' "$END"
}

inject() { # <file> — print <file> with the marker region replaced by gen_table
  local file="$1" tf
  if ! grep -qF "$START" "$file" || ! grep -qF "$END" "$file"; then
    echo "✘ $file has no trigger marker region" >&2
    return 1
  fi
  tf="$(mktemp)"
  gen_table > "$tf"        # the table file already includes START..END markers
  awk -v s="$START" -v e="$END" -v tf="$tf" '
    $0==s { while ((getline line < tf) > 0) print line; close(tf); skip=1; next }
    $0==e { skip=0; next }
    !skip { print }
  ' "$file"
  rm -f "$tf"
}

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

# Fail loudly if ORDER references a skill that doesn't exist, instead of
# silently dropping it from the generated table (the `[ -f "$f" ] || continue`
# in gen_table stays as a defensive fallback but should now be unreachable).
for s in $ORDER; do
  f="$ROOT/skills/$s/SKILL.md"
  [ -f "$f" ] || { echo "✘ ORDER references missing skill: $s" >&2; exit 1; }
done

rc=0
rel="README.md"
file="$ROOT/$rel"
if [ ! -f "$file" ]; then
  echo "✘ missing $rel" >&2
  rc=1
elif ! new="$(inject "$file")"; then
  rc=1
elif [ "$CHECK" -eq 1 ]; then
  if ! diff -q "$file" <(printf '%s\n' "$new") >/dev/null; then
    echo "✘ $rel trigger table is stale — run: bash scripts/gen-trigger-docs.sh" >&2
    rc=1
  else
    echo "✔ $rel trigger table up to date"
  fi
else
  printf '%s\n' "$new" > "$file"
  echo "✔ wrote $rel"
fi
exit "$rc"
