#!/usr/bin/env bash
# description由来の起動規則と、Gitを呼ばない起動処理を確認する。
# 起動情報の配線を保ち、不要なGit操作の再導入を防ぐために使う。

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
	assert_contains "$skill keeps external-change authority explicit" \
		'公開・配布・本番環境や共有データを変更する操作は、利用者が依頼の終点として明示した場合だけ行う' \
		"$(cat "$ROOT/skills/$skill/SKILL.md")"
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/bin"
cat > "$TMP/bin/git" <<'EOF'
#!/usr/bin/env bash
# 起動処理からのGit呼び出しを記録する。
# fetchを含むGit操作が戻っていないことを確かめる。
printf 'called\n' >> "$HZ_GIT_LOG"
exit 1
EOF
chmod +x "$TMP/bin/git"
export HZ_GIT_LOG="$TMP/git.log"
export PATH="$TMP/bin:$PATH"
CLAUDE=$(bash "$SESSION" claude </dev/null)
assert_eq "Claude receives only routing" "$(cat "$ROUTING")" "$CLAUDE"
CODEX=$(bash "$SESSION" codex <<<'{"cwd":"/nonexistent"}')
assert_eq "Codex event is SessionStart" "SessionStart" \
  "$(printf '%s' "$CODEX" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "Codex receives only routing" "$(cat "$ROUTING")" \
  "$(printf '%s' "$CODEX" | jq -r '.hookSpecificOutput.additionalContext')"
[ ! -e "$HZ_GIT_LOG" ]
assert_exit "startup does not call Git" 0 "$?"
hz_test_summary
