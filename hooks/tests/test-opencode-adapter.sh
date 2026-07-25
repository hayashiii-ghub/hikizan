#!/usr/bin/env bash
# OpenCode's plugin API cannot return an interactive ask decision. This adapter
# translates the shared floors into thrown errors and supplies the same short
# skill-routing context as the other supported harnesses.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
INVOKE="$DIR/opencode-invoke.ts"

if ! command -v bun >/dev/null 2>&1; then
  printf 'skip: opencode-adapter requires bun\n'
  hz_test_summary
  exit 0
fi

hz_mkrepo() {
  local branch="$1" dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name t
  git -C "$dir" commit -q --allow-empty -m init
  git -C "$dir" branch -M "$branch"
  printf '%s' "$dir"
}

invoke() {
  bun "$INVOKE" "$1" "$ROOT" "$REPO" "${2:-}" 2>/dev/null
}

REPO="$(hz_mkrepo main)"

OUT="$(invoke before 'git push --force origin main')"
assert_eq "force push is denied" "deny" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"

OUT="$(invoke before 'git push origin feature')"
assert_eq "benign push is allowed" "allow" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"

OUT="$(invoke before 'rm -rf /tmp/hikizan-opencode-test')"
assert_eq "destructive operation is denied" "deny" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"
assert_contains "destructive reason names OpenCode" "OpenCode" "$(printf '%s' "$OUT" | jq -r '.reason // ""')"

OUT="$(invoke before 'gh pr create --title x')"
assert_eq "non-draft PR is denied" "deny" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"

OUT="$(invoke before-non-bash 'rm -rf /tmp/hikizan-opencode-test')"
assert_eq "non-bash tool is ignored" "allow" "$(printf '%s' "$OUT" | jq -r '.decision // "crash"')"

OUT="$(invoke surface)"
assert_eq "adapter exposes the floor and routing hooks" \
  '["experimental.chat.system.transform","tool.execute.before"]' \
  "$(printf '%s' "$OUT" | jq -c '.hooks // []')"

OUT="$(invoke routing)"
assert_eq "OpenCode receives the shared routing text" "$(cat "$ROOT/hooks/routing.md")" \
  "$(printf '%s' "$OUT" | jq -r '.system[0] // ""')"

rm -rf "$REPO"
hz_test_summary
