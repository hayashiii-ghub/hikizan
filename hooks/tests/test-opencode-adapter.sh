#!/usr/bin/env bash
# OpenCodeアダプターが起動情報だけを持つことを確認する。
# ハーネス固有の配線へシェル実行前の判定が戻らないようにするために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
INVOKE="$DIR/opencode-invoke.ts"

if ! command -v bun >/dev/null 2>&1; then
  printf 'skip: opencode-adapter requires bun\n'
  hz_test_summary
  exit 0
fi

REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" config user.email test@localhost
git -C "$REPO" config user.name test
git -C "$REPO" commit -q --allow-empty -m init

invoke() {
  HIKIZAN_SKIP_FETCH=1 bun "$INVOKE" "$1" "$ROOT" "$REPO" "${2:-}" 2>/dev/null
}

OUT=$(invoke surface)
assert_eq "adapter exposes only session context" \
  '["experimental.chat.system.transform"]' \
  "$(printf '%s' "$OUT" | jq -c '.hooks // []')"
OUT=$(invoke routing)
SYSTEM=$(printf '%s' "$OUT" | jq -r '.system[0] // ""')
assert_contains "OpenCode receives routing" "## hikizanのスキル選択" "$SYSTEM"
assert_contains "OpenCode receives repository status" "リポジトリ:" "$SYSTEM"

rm -rf "$REPO"
hz_test_summary
