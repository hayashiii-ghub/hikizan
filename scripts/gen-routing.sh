#!/usr/bin/env bash
# 各SKILL.mdの起動条件から、全ハーネス共通の短いルーティング規則と
# Cursor向けalways-apply ruleを生成する。
#
#   bash scripts/gen-routing.sh
#   bash scripts/gen-routing.sh --check

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORDER="$(jq -r '.core | join(" ")' "$ROOT/scripts/skills.json")"
ROUTING="$ROOT/hooks/routing.md"
CURSOR_RULE="$ROOT/hooks/adapters/cursor/rules/hikizan.mdc"

[ -n "$ORDER" ] || { echo "✘ failed to read core skills from scripts/skills.json" >&2; exit 1; }

fm_field() {
  awk -v fld="$2" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm && $0 ~ "^"fld":" {
      sub("^"fld":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit
    }' "$1"
}

gen_routing() {
  printf '%s\n' '<!-- scripts/gen-routing.shが各SKILL.mdのwhen_to_useから生成。手動編集しない -->'
  printf '%s\n\n' '## hikizanのスキル選択'
  printf '%s\n\n' '利用者の依頼が次の条件に当てはまる場合は、対応するhikizanスキルの`SKILL.md`を最後まで読んでから作業する。通常作業に不要なスキルを固定順で通さない。依頼に「計画だけ」「修正まで」「PRまで」のような終点があれば、必要なスキルを組み合わせ、明示済みの終点まで形式的な承認待ちを挟まず進める。'
  for skill in $ORDER; do
    file="$ROOT/skills/$skill/SKILL.md"
    [ -f "$file" ] || { echo "✘ missing skill: $skill" >&2; return 1; }
    when="$(fm_field "$file" when_to_use)"
    [ -n "$when" ] || { echo "✘ missing when_to_use: $skill" >&2; return 1; }
    printf -- '- `%s`：%s\n' "$skill" "$when"
  done
  printf '\n%s\n' '複数の観点が必要なら該当するスキルを組み合わせてよい。起動するスキルごとに、その作業を始める直前に別の1行で`🌲 <スキル名>（日本語名）：<今回の目的>`と表示する。複数スキルを1行にまとめたり、まだ始めないスキルを予告したりしない。停止するときは、意味のある次の進め方だけを選び、推奨順に`A`、`B`、`C`を付けて返す。'
}

gen_cursor_rule() {
  printf '%s\n' '---'
  printf '%s\n' 'description: hikizanのスキル起動条件'
  printf '%s\n' 'alwaysApply: true'
  printf '%s\n' '---'
  printf '%s\n\n' '<!-- scripts/gen-routing.shによる生成物。手動編集しない -->'
  gen_routing
}

check_one() {
  local path="$1" generator="$2"
  if diff -q "$path" <("$generator") >/dev/null 2>&1; then
    echo "✔ ${path#$ROOT/} up to date"
  else
    echo "✘ ${path#$ROOT/} is stale — run: bash scripts/gen-routing.sh" >&2
    return 1
  fi
}

if [ "${1:-}" = "--check" ]; then
  rc=0
  check_one "$ROUTING" gen_routing || rc=1
  check_one "$CURSOR_RULE" gen_cursor_rule || rc=1
  exit "$rc"
fi

mkdir -p "$(dirname "$CURSOR_RULE")"
tmp_routing="$(mktemp "$ROUTING.tmp.XXXXXX")"
tmp_cursor="$(mktemp "$CURSOR_RULE.tmp.XXXXXX")"
cleanup() {
  rm -f -- "$tmp_routing" "$tmp_cursor"
}
trap cleanup EXIT
gen_routing > "$tmp_routing"
gen_cursor_rule > "$tmp_cursor"
chmod 0644 "$tmp_routing" "$tmp_cursor"
mv "$tmp_routing" "$ROUTING"
mv "$tmp_cursor" "$CURSOR_RULE"
trap - EXIT
echo "✔ wrote hooks/routing.md and hooks/adapters/cursor/rules/hikizan.mdc"
