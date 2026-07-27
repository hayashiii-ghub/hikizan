#!/usr/bin/env bash
# OpenCodeアダプターが起動情報とマージ停止だけを持つことを確認する。
# ハーネス固有の配線へ不要なHook責務が戻らないようにするために使う。

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

OUT=$(invoke before 'gh pr merge 123')
assert_eq "PR merge is denied" "deny" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"
OUT=$(invoke before 'git push origin feature')
assert_eq "normal push is allowed" "allow" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"
OUT=$(invoke before 'gh pr create --title x')
assert_eq "PR creation is allowed" "allow" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"
OUT=$(invoke before 'rm -rf build')
assert_eq "destructive command is outside this hook" "allow" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"
OUT=$(invoke before-non-bash 'gh pr merge 123')
assert_eq "non-bash tool is ignored" "allow" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"

OUT=$(invoke surface)
assert_eq "adapter exposes context and pre-tool hooks" \
  '["experimental.chat.system.transform","tool.execute.before"]' \
  "$(printf '%s' "$OUT" | jq -c '.hooks // []')"
OUT=$(invoke routing)
SYSTEM=$(printf '%s' "$OUT" | jq -r '.system[0] // ""')
assert_contains "OpenCode receives routing" "## hikizanのスキル選択" "$SYSTEM"
assert_contains "OpenCode receives repository status" "リポジトリ:" "$SYSTEM"

rm -rf "$REPO"
hz_test_summary
