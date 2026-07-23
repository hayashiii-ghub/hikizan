#!/usr/bin/env bash
# Tests for the Codex floors adapter. Codex's PreToolUse input/output is
# mostly compatible with Claude Code's (tool_input.command / cwd / session_id
# in, hookSpecificOutput.permissionDecision out). Codex does not support the
# PreToolUse "ask" decision, so the shared destructive classifier is invoked
# in deny mode while the other floor scripts are reused unchanged. This file
# exercises them through a Codex-shaped payload.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
PRE_PUSH="$ROOT/hooks/scripts/pre-push.sh"
PRE_DESTRUCTIVE="$ROOT/hooks/scripts/pre-destructive.sh"
PRE_PR_CREATE="$ROOT/hooks/scripts/pre-pr-create.sh"

hz_mkrepo() { local b="$1" d; d="$(mktemp -d)"; git -C "$d" init -q
  git -C "$d" config user.email t@example.com; git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init; git -C "$d" branch -M "$b"; printf '%s' "$d"; }

# run_codex_pretooluse <hook> <command> <cwd> [hook args...] -> sets HZ_OUT to the hook's
# stdout. Builds the Codex PreToolUse payload shape from the spec.
run_codex_pretooluse() {
  local hook="$1" cmd="$2" cwd="$3" payload
  shift 3
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

run_codex_pretooluse "$PRE_PUSH" 'env FOO=x git push --force origin main' "$REPO_MAIN"
assert_eq "pre-push: env wrapped force push -> deny" "deny" "$(decision_of "$HZ_OUT")"

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


run_codex_pretooluse "$PRE_DESTRUCTIVE" "ls -la" "/tmp"
assert_eq "pre-destructive: ls -la -> allow" "allow" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_DESTRUCTIVE" "git reset --hard&&echo ok" "/tmp" deny
assert_eq "pre-destructive: adjacent reset --hard -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_DESTRUCTIVE" "if true; then rm -rf /tmp/x; fi" "/tmp" deny
assert_eq "pre-destructive: reserved-word wrapped rm -rf -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_DESTRUCTIVE" 'env -S "rm -rf /tmp/x"' "/tmp" deny
assert_eq "pre-destructive: env split-string rm -rf -> deny" "deny" "$(decision_of "$HZ_OUT")"

run_codex_pretooluse "$PRE_DESTRUCTIVE" 'env -P /bin rm -rf /tmp/x' "/tmp" deny
assert_eq "pre-destructive: env utility-path rm -rf -> deny" "deny" "$(decision_of "$HZ_OUT")"

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

hz_test_summary
