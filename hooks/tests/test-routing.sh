#!/usr/bin/env bash
# description由来の起動規則と、セッション開始時のGit状態を確認する。
# スキル選択と作業開始時の前提がハーネス間でずれないようにするために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
ROUTING="$ROOT/hooks/routing.md"
SESSION="$ROOT/hooks/scripts/session-routing.sh"

bash "$ROOT/scripts/gen-routing.sh" --check >/dev/null 2>&1
assert_exit "routing artifacts are current" 0 "$?"
assert_eq "when_to_use is absent from skills" "" \
  "$(grep -Rl '^when_to_use:' "$ROOT/skills" || true)"

for skill in $(jq -r '.core[]' "$ROOT/scripts/skills.json"); do
  description=$(awk '
    NR==1 && $0=="---" {inside=1; next}
    inside && $0=="---" {exit}
    inside && /^description:/ {sub(/^description:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit}
  ' "$ROOT/skills/$skill/SKILL.md")
  assert_contains "routing uses $skill description" "$description" "$(cat "$ROUTING")"
done

TMP=$(mktemp -d)
REMOTE="$TMP/remote.git"
WORK="$TMP/work"
OTHER="$TMP/other"
git init -q --bare -b main "$REMOTE"
git init -q "$WORK"
git -C "$WORK" config user.email test@localhost
git -C "$WORK" config user.name test
printf 'base\n' > "$WORK/file.txt"
git -C "$WORK" add file.txt
git -C "$WORK" commit -qm base
git -C "$WORK" branch -M main
git -C "$WORK" remote add origin "$REMOTE"
git -C "$WORK" push -qu --set-upstream origin main
git clone -q "$REMOTE" "$OTHER"
git -C "$OTHER" config user.email test@localhost
git -C "$OTHER" config user.name test
printf 'remote\n' >> "$OTHER/file.txt"
git -C "$OTHER" commit -qam remote
git -C "$OTHER" push -q origin main
printf 'dirty\n' >> "$WORK/file.txt"
PAYLOAD=$(jq -nc --arg cwd "$WORK" '{cwd:$cwd}')

CLAUDE=$(printf '%s' "$PAYLOAD" | bash "$SESSION" claude)
assert_contains "Claude receives routing" "## hikizanのスキル選択" "$CLAUDE"
assert_contains "routing limits integration operations" "PRのマージと既定ブランチへの直接のpush" "$CLAUDE"
assert_contains "routing does not treat PR creation as merge approval" "「PRまで」はマージを含めない" "$CLAUDE"
assert_contains "Claude receives repository name" "リポジトリ: work" "$CLAUDE"
assert_contains "dirty worktree is reported" "worktree=変更あり" "$CLAUDE"
assert_contains "remote fetch updates behind count" "behind=1" "$CLAUDE"
assert_contains "successful fetch is reported" "remote=確認済み" "$CLAUDE"

CODEX=$(HIKIZAN_SKIP_FETCH=1 bash "$SESSION" codex <<<"$PAYLOAD")
assert_eq "Codex event is SessionStart" "SessionStart" \
  "$(printf '%s' "$CODEX" | jq -r '.hookSpecificOutput.hookEventName')"
assert_contains "Codex receives routing" "## hikizanのスキル選択" \
  "$(printf '%s' "$CODEX" | jq -r '.hookSpecificOutput.additionalContext')"

CURSOR=$(HIKIZAN_SKIP_FETCH=1 bash "$SESSION" cursor <<<"$PAYLOAD")
CURSOR_CONTEXT=$(printf '%s' "$CURSOR" | jq -r '.additional_context')
assert_contains "Cursor receives dynamic repository status" "リポジトリ: work" "$CURSOR_CONTEXT"
case "$CURSOR_CONTEXT" in
  *'## hikizanのスキル選択'*) HZ_FAIL=$((HZ_FAIL + 1)); printf '  FAIL: Cursor dynamic context duplicates its generated rule\n' ;;
  *) HZ_PASS=$((HZ_PASS + 1)) ;;
esac

rm -rf "$TMP"
hz_test_summary
