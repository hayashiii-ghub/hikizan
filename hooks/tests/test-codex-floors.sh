#!/usr/bin/env bash
# Tests for the Codex floors adapter. Codex's PreToolUse input/output is
# mostly compatible with Claude Code's (tool_input.command / cwd / session_id
# in, hookSpecificOutput.permissionDecision out). Codex does not support the
# PreToolUse "ask" decision, so the shared destructive classifier is invoked
# in deny mode while the other floor scripts are reused unchanged. This file
# exercises them through a Codex-shaped payload and pins the SessionStart
# preamble adapter.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
PRE_PUSH="$ROOT/hooks/scripts/pre-push.sh"
PRE_DESTRUCTIVE="$ROOT/hooks/scripts/pre-destructive.sh"
PRE_PR_CREATE="$ROOT/hooks/scripts/pre-pr-create.sh"
SESSION_CONTEXT="$ROOT/codex/scripts/session-context.sh"
CODEX_HOOKS="$ROOT/codex/hooks.json"

assert_eq "codex SessionStart is startup-only" "startup" \
  "$(jq -r '.hooks.SessionStart[0].matcher' "$CODEX_HOOKS")"

hz_mkrepo() { local b="$1" d; d="$(mktemp -d)"; git -C "$d" init -q
  git -C "$d" config user.email t@example.com; git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init; git -C "$d" branch -M "$b"; printf '%s' "$d"; }

# run_codex_pretooluse <hook> <command> <cwd> [hook args...] -> sets HZ_OUT to the hook's
# stdout. Builds the Codex PreToolUse payload shape from the spec.
run_codex_pretooluse() {
  local hook="$1" cmd="$2" cwd="$3" payload
  shift 3
  : "${HIKIZAN_METRICS_DIR:=$(mktemp -d 2>/dev/null || echo /tmp/hz-metrics.$$)}"
  export HIKIZAN_METRICS_DIR
  payload=$(jq -nc --arg c "$cmd" --arg w "$cwd" \
    '{session_id:"s", tool_name:"Bash", tool_input:{command:$c}, cwd:$w, hook_event_name:"PreToolUse", permission_mode:"default"}')
  HZ_OUT=$(printf '%s' "$payload" | bash "$hook" "$@" 2>/dev/null)
}

decision_of() {
  if [ -z "$1" ]; then echo allow; return; fi
  printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || echo allow
}

# --- pre-push.sh ---
REPO_MAIN="$(hz_mkrepo main)"
REPO_FEAT="$(hz_mkrepo feature)"
git -C "$REPO_FEAT" branch main

run_codex_pretooluse "$PRE_PUSH" "git push --force origin main" "$REPO_MAIN"
assert_eq "pre-push: force origin main -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PUSH" 'echo "$(git push --force origin main)"' "$REPO_MAIN"
assert_eq "pre-push: nested force origin main -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PUSH" 'git -C /tmp/a -C ../b push --force origin main' "$REPO_MAIN"
assert_eq "pre-push: unresolved git context -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PUSH" 'git push --force origin "main"' "$REPO_MAIN"
assert_eq "pre-push: force origin quoted \"main\" -> deny (quote evasion closed)" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PUSH" "git push origin main" "$REPO_MAIN"
assert_eq "pre-push: plain push origin main -> allow" "allow" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PUSH" "git push --force --all origin" "$REPO_FEAT"
assert_eq "pre-push: --force --all from feature -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PUSH" "git push --force origin main&&echo ok" "$REPO_FEAT"
assert_eq "pre-push: adjacent protected push -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PUSH" "git push --all origin" "$REPO_FEAT"
assert_eq "pre-push: plain --all from feature -> allow" "allow" "$(decision_of "$HZ_OUT")"

rm -rf "$REPO_MAIN" "$REPO_FEAT"

# --- pre-destructive.sh ---
run_codex_pretooluse "$PRE_DESTRUCTIVE" "rm -rf /tmp/x" "/tmp" deny
assert_eq "pre-destructive: rm -rf -> deny (Codex has no ask decision)" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_DESTRUCTIVE" 'echo "$(rm -rf /tmp/x)"' "/tmp" deny
assert_eq "pre-destructive: nested rm -rf -> deny" "deny" "$(decision_of "$HZ_OUT")"
assert_contains "pre-destructive: deny reason explains the Codex path" "blocked" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
assert_contains "pre-destructive: deny reason forbids agent bypass" "do not retry" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

CODEX_METRICS_DIR="$(mktemp -d)"
printf '%s' "$(jq -nc '{session_id:"deadbeef-0000-0000-0000-000000000000",tool_input:{command:"rm -rf /tmp/x"}}')" | \
  HIKIZAN_METRICS_DIR="$CODEX_METRICS_DIR" bash "$PRE_DESTRUCTIVE" deny >/dev/null 2>&1
assert_eq "pre-destructive: Codex deny is recorded as metrics block" "block" \
  "$(jq -r '.decision' "$CODEX_METRICS_DIR/metrics.jsonl")"

run_codex_pretooluse "$PRE_DESTRUCTIVE" "ls -la" "/tmp"
assert_eq "pre-destructive: ls -la -> allow" "allow" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_DESTRUCTIVE" "git reset --hard&&echo ok" "/tmp" deny
assert_eq "pre-destructive: adjacent reset --hard -> deny" "deny" "$(decision_of "$HZ_OUT")"

# --- pre-pr-create.sh ---
run_codex_pretooluse "$PRE_PR_CREATE" "gh pr create --title x" "/tmp"
assert_eq "pre-pr-create: no draft/reviewer -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PR_CREATE" 'echo "$(gh pr create --title x)"' "/tmp"
assert_eq "pre-pr-create: nested no draft/reviewer -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PR_CREATE" "gh pr create --draft --title x" "/tmp"
assert_eq "pre-pr-create: --draft -> allow" "allow" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PR_CREATE" "gh pr create --title x&&echo --draft" "/tmp"
assert_eq "pre-pr-create: later --draft does not approve -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_PR_CREATE" "gh pr create --title x # --draft" "/tmp"
assert_eq "pre-pr-create: commented --draft does not approve -> deny" "deny" "$(decision_of "$HZ_OUT")"

# --- codex/scripts/session-context.sh (SessionStart) ---
run_codex_sessionstart() { # <cwd> -> sets HZ_OUT
  local cwd="$1" payload
  payload=$(jq -nc --arg w "$cwd" \
    '{session_id:"s", cwd:$w, hook_event_name:"SessionStart", source:"startup"}')
  HZ_OUT=$(printf '%s' "$payload" | bash "$SESSION_CONTEXT" 2>/dev/null)
}

run_codex_sessionstart "/tmp"
EVENT="$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.hookEventName // ""' 2>/dev/null)"
assert_eq "session-context: hookEventName == SessionStart" "SessionStart" "$EVENT"
CTX="$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)"
if [ -n "$CTX" ]; then HZ_PASS=$((HZ_PASS + 1)); else HZ_FAIL=$((HZ_FAIL + 1)); printf '  FAIL: session-context: additionalContext must be non-empty\n'; fi
assert_contains "session-context: additionalContext mentions hikizan" "hikizan" "$CTX"

CTX_STD="$(HIKIZAN_TIER=standard bash -c "printf '%s' \"\$1\" | bash \"\$2\"" _ \
  "$(jq -nc '{session_id:"s", cwd:"/tmp", hook_event_name:"SessionStart", source:"startup"}')" \
  "$SESSION_CONTEXT" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)"
PREAMBLE_LINE1="$(head -1 "$ROOT/context/standard-preamble.md")"
assert_contains "session-context: standard tier includes preamble" "$PREAMBLE_LINE1" "$CTX_STD"

CTX_GUIDED="$(HIKIZAN_TIER=guided bash -c "printf '%s' \"\$1\" | bash \"\$2\"" _ \
  "$(jq -nc '{session_id:"s", cwd:"/tmp", hook_event_name:"SessionStart", source:"startup"}')" \
  "$SESSION_CONTEXT" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)"
case "$CTX_GUIDED" in
  *"$PREAMBLE_LINE1"*)
    HZ_FAIL=$((HZ_FAIL + 1))
    printf '  FAIL: session-context: guided tier must NOT include preamble\n'
    ;;
  *) HZ_PASS=$((HZ_PASS + 1)) ;;
esac

hz_test_summary
