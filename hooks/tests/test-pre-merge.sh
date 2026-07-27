#!/usr/bin/env bash
# PRマージ前の共通Hookが、未承認を止め承認後を通すか確認する。
# ハーネス別の確認方法を保ち、明示承認後だけ再実行を許すために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../scripts/pre-merge.sh"

hz_run_hook "$HOOK" "gh pr merge 123 --squash" "/tmp"
assert_eq "Claude asks before PR merge" "ask" "$(hz_decision_of "$HZ_OUT")"
assert_contains "ask explains the checkpoint" "確認" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

payload=$(jq -nc '{tool_input:{command:"gh pr merge 123"},cwd:"/tmp"}')
HZ_OUT=$(printf '%s' "$payload" | bash "$HOOK" deny Codex)
assert_eq "non-interactive harness denies PR merge" "deny" "$(hz_decision_of "$HZ_OUT")"
assert_contains "deny returns execution to the user" "利用者" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

hz_run_hook "$HOOK" "HIKIZAN_MERGE_APPROVED=1 gh pr merge 123 --squash" "/tmp"
assert_eq "approved PR merge is allowed" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "HIKIZAN_MERGE_APPROVED=0 gh pr merge 123 --squash" "/tmp"
assert_eq "invalid approval value is denied" "ask" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push origin feature" "/tmp"
assert_eq "normal push is allowed" "allow" "$(hz_decision_of "$HZ_OUT")"
hz_run_hook "$HOOK" "gh pr create --title x" "/tmp"
assert_eq "PR creation is allowed" "allow" "$(hz_decision_of "$HZ_OUT")"
hz_run_hook "$HOOK" "rm -rf build" "/tmp"
assert_eq "destructive shell command is outside this hook" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_test_summary
