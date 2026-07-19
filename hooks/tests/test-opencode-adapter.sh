#!/usr/bin/env bash
# OpenCode TypeScript adapter integration tests. The adapter translates the
# shared shell floors into OpenCode hook behavior without reimplementing their
# classification logic.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
INVOKE="$ROOT/opencode/tests/invoke.ts"

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

invoke_before() {
  bun "$INVOKE" before "$ROOT" "$1" "$2" 2>/dev/null
}

invoke() {
  bun "$INVOKE" "$1" "$2" "$3" "${4:-}" 2>/dev/null
}

REPO_MAIN="$(hz_mkrepo main)"

OUT="$(invoke_before "$REPO_MAIN" 'git push --force origin main')"
assert_eq "force push deny maps to OpenCode throw" "deny" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"

OUT="$(invoke_before "$REPO_MAIN" 'git push origin feature')"
assert_eq "benign push returns without throwing" "allow" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"

OUT="$(invoke_before "$REPO_MAIN" 'rm -rf /tmp/hikizan-opencode-test')"
assert_eq "destructive operation is denied" "deny" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"
assert_contains "destructive reason names OpenCode" "OpenCode" \
  "$(printf '%s' "$OUT" | jq -r '.reason // ""' 2>/dev/null)"
case "$(printf '%s' "$OUT" | jq -r '.reason // ""' 2>/dev/null)" in
  *Codex*) HZ_FAIL=$((HZ_FAIL + 1)); printf '  FAIL: destructive reason must not name Codex\n' ;;
  *) HZ_PASS=$((HZ_PASS + 1)) ;;
esac

OUT="$(invoke_before "$REPO_MAIN" 'gh pr create --title x')"
assert_eq "non-draft PR is denied" "deny" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"

OUT="$(invoke before-non-bash "$ROOT" "$REPO_MAIN" 'rm -rf /tmp/hikizan-opencode-test')"
assert_eq "non-bash tool is ignored" "allow" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"

OUT="$(invoke before /tmp/hikizan-missing-root "$REPO_MAIN" 'rm -rf /tmp/hikizan-opencode-test')"
assert_eq "missing explicit root fails open" "allow" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"

PARTIAL_ROOT="$(mktemp -d)"
mkdir -p "$PARTIAL_ROOT/hooks/scripts" "$PARTIAL_ROOT/context"
cp "$ROOT/hooks/scripts/pre-push.sh" "$PARTIAL_ROOT/hooks/scripts/pre-push.sh"
cp "$ROOT/context/routing.md" "$PARTIAL_ROOT/context/routing.md"
OUT="$(invoke before "$PARTIAL_ROOT" "$REPO_MAIN" 'git push origin feature')"
assert_eq "partial explicit root fails open as unavailable" "allow" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"

SCHEMA_ROOT="$(mktemp -d)"
mkdir -p "$SCHEMA_ROOT/hooks/scripts" "$SCHEMA_ROOT/context"
for script in pre-push.sh pre-pr-create.sh pre-destructive.sh post-command.sh session-context.sh; do
  cp "$ROOT/hooks/scripts/$script" "$SCHEMA_ROOT/hooks/scripts/$script"
done
cp "$ROOT/context/routing.md" "$SCHEMA_ROOT/context/routing.md"
printf '%s\n' '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}'\''' \
  > "$SCHEMA_ROOT/hooks/scripts/pre-push.sh"
OUT="$(invoke before "$SCHEMA_ROOT" "$REPO_MAIN" 'git push origin feature')"
assert_eq "unsupported hook decision fails closed" "deny" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"
assert_contains "unsupported decision reports adapter contract error" "invalid decision" \
  "$(printf '%s' "$OUT" | jq -r '.reason // ""' 2>/dev/null)"

METRICS_DIR="$(mktemp -d)"
HIKIZAN_METRICS_DIR="$METRICS_DIR" invoke after "$ROOT" "$REPO_MAIN" 'rm -rf /tmp/hikizan-opencode-test' >/dev/null
assert_eq "after hook records executed floor class" "command_executed" \
  "$(jq -r '.event // ""' "$METRICS_DIR/metrics.jsonl" 2>/dev/null)"
assert_eq "after hook records OpenCode deny policy" "block" \
  "$(jq -r '.decision // ""' "$METRICS_DIR/metrics.jsonl" 2>/dev/null)"
assert_eq "after hook preserves OpenCode session id" "ses_01JTESTABCDEF23456789" \
  "$(jq -r '.session_id // ""' "$METRICS_DIR/metrics.jsonl" 2>/dev/null)"

OUT="$(invoke system "$ROOT" "$REPO_MAIN")"
assert_contains "system hook injects routing on first call" "hikizan" \
  "$(printf '%s' "$OUT" | jq -r '.first // ""' 2>/dev/null)"
assert_contains "system hook reuses context on later call" "hikizan" \
  "$(printf '%s' "$OUT" | jq -r '.second // ""' 2>/dev/null)"

CONTEXT_METRICS_DIR="$(mktemp -d)"
HIKIZAN_METRICS_DIR="$CONTEXT_METRICS_DIR" invoke system "$ROOT" "$REPO_MAIN" >/dev/null
assert_eq "system context shell result is cached per session" "1" \
  "$(wc -l < "$CONTEXT_METRICS_DIR/metrics.jsonl" | tr -d ' ')"

NOJQ_BIN="$(mktemp -d)"
ln -s "$(command -v bash)" "$NOJQ_BIN/bash"
ln -s "$(command -v dirname)" "$NOJQ_BIN/dirname"
BUN_BIN="$(command -v bun)"
OUT="$(PATH="$NOJQ_BIN" "$BUN_BIN" "$INVOKE" before "$ROOT" "$REPO_MAIN" 'ls -la' 2>/dev/null)"
assert_eq "missing jq fails closed through OpenCode throw" "deny" \
  "$(printf '%s' "$OUT" | jq -r '.decision // "crash"' 2>/dev/null)"
assert_contains "missing jq reason is preserved" "jq not found" \
  "$(printf '%s' "$OUT" | jq -r '.reason // ""' 2>/dev/null)"

rm -rf "$REPO_MAIN" "$PARTIAL_ROOT" "$SCHEMA_ROOT" "$METRICS_DIR" "$CONTEXT_METRICS_DIR" "$NOJQ_BIN"
hz_test_summary
