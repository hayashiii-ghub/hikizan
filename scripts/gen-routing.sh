#!/usr/bin/env bash
# 各SKILL.mdのdescriptionから、共通の起動規則とCursor向け規則を生成する。
# スキルの呼び分けをハーネスごとに手作業で同期しないために使う。

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
  printf '%s\n' '<!-- scripts/gen-routing.shが各SKILL.mdのdescriptionから生成。手動編集しない -->'
  printf '%s\n\n' '## hikizanのスキル選択'
  printf '%s\n\n' '利用者の依頼が次の説明に当てはまる場合は、対応する`SKILL.md`を最後まで読んでから作業する。必要なスキルだけを使い、調査、相談、設計、レビューだけの依頼では対象を変更しない。修正やPR提出まで明示されていれば、必要なスキルをつないでその終点まで進む。'
  for skill in $ORDER; do
    file="$ROOT/skills/$skill/SKILL.md"
    [ -f "$file" ] || { echo "✘ missing skill: $skill" >&2; return 1; }
    description="$(fm_field "$file" description)"
    [ -n "$description" ] || { echo "✘ missing description: $skill" >&2; return 1; }
    printf -- '- `%s`：%s\n' "$skill" "$description"
  done
  printf '\n%s\n\n' 'PRのマージと既定ブランチへの直接のpushは、利用者が依頼の終点として明示した場合だけ行う。「PRまで」はマージを含めない。明示済みなら同じ依頼内で再確認しない。'
  printf '%s\n' '起動するスキルごとに、作業の直前に1行だけ`🌲 <スキル名>（日本語名）：<今回の目的>`と表示する。停止時に意味のある次の進め方があれば、最大3件を推奨順に`A（あ）`、`B（い）`、`C（う）`で示し、英字とひらがなのどちらの回答も同じ選択として扱う。'
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
