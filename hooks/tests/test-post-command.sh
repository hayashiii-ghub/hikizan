#!/usr/bin/env bash
# Integration tests for post-command.sh (PostToolUse observation hook).
# Only executions matching a floor target class get one metrics line; every
# other command must record nothing, and the hook must always exit 0 (it
# makes no decision — the tool already ran).

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../scripts/post-command.sh"

# run_post <command> [cwd] -> sets HZ_CODE and METRICS_FILE (fresh dir each call)
run_post() {
  local cmd="$1" cwd="${2:-/tmp}"
  HIKIZAN_METRICS_DIR="$(mktemp -d)"
  export HIKIZAN_METRICS_DIR
  METRICS_FILE="$HIKIZAN_METRICS_DIR/metrics.jsonl"
  local payload
  # UUID-shaped session_id so lib/metrics.sh's synthetic-id guard admits the
  # write (a short id like "test" is dropped by design; see test-metrics-guard.sh).
  payload=$(jq -nc --arg c "$cmd" --arg w "$cwd" \
    '{tool_input:{command:$c}, cwd:$w, session_id:"deadbeef-0000-0000-0000-000000000000"}')
  printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>/dev/null
  HZ_CODE=$?
}

# line count of metrics file, or 0 if it doesn't exist
metrics_lines() {
  [ -f "$METRICS_FILE" ] || { printf '0'; return; }
  wc -l < "$METRICS_FILE" | tr -d ' '
}

# 1. rm -rf -> 1 line, event=command_executed hook=post-command
#    condition=destructive decision=ask
run_post "rm -rf /tmp/x"
assert_eq "rm -rf: exit 0" "0" "$HZ_CODE"
assert_eq "rm -rf: 1 metrics line" "1" "$(metrics_lines)"
assert_eq "rm -rf: event" "command_executed" "$(jq -r '.event' "$METRICS_FILE")"
assert_eq "rm -rf: hook" "post-command" "$(jq -r '.hook' "$METRICS_FILE")"
assert_eq "rm -rf: condition" "destructive" "$(jq -r '.condition' "$METRICS_FILE")"
assert_eq "rm -rf: decision" "ask" "$(jq -r '.decision' "$METRICS_FILE")"

# 2. force push to a protected branch -> 1 line, condition=force_protected
#    decision=block
run_post "git push --force origin main"
assert_eq "force push: exit 0" "0" "$HZ_CODE"
assert_eq "force push: 1 metrics line" "1" "$(metrics_lines)"
assert_eq "force push: condition" "force_protected" "$(jq -r '.condition' "$METRICS_FILE")"
assert_eq "force push: decision" "block" "$(jq -r '.decision' "$METRICS_FILE")"

# 3. non-draft gh pr create with no reviewer -> 1 line,
#    condition=no_draft_no_reviewer decision=block
run_post 'gh pr create --title "x"'
assert_eq "pr create no draft/reviewer: exit 0" "0" "$HZ_CODE"
assert_eq "pr create no draft/reviewer: 1 metrics line" "1" "$(metrics_lines)"
assert_eq "pr create no draft/reviewer: condition" "no_draft_no_reviewer" "$(jq -r '.condition' "$METRICS_FILE")"
assert_eq "pr create no draft/reviewer: decision" "block" "$(jq -r '.decision' "$METRICS_FILE")"

# 4. benign command -> 0 lines recorded
run_post "ls -la"
assert_eq "ls: exit 0" "0" "$HZ_CODE"
assert_eq "ls: 0 metrics lines" "0" "$(metrics_lines)"

# 5. floor-allowed class (draft PR) -> 0 lines recorded (allow is not logged)
run_post "gh pr create --draft --title \"x\""
assert_eq "pr create --draft: exit 0" "0" "$HZ_CODE"
assert_eq "pr create --draft: 0 metrics lines" "0" "$(metrics_lines)"

hz_test_summary
