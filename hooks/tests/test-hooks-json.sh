#!/usr/bin/env bash
# Pin test for hooks/hooks.json wiring itself (not the scripts it points at).
# JSON validity, matcher typos, or wrong script paths would otherwise stay
# silent in this suite while the floors quietly stop firing in production.
#
# NOTE TO FUTURE EDITORS: if you add/remove/rename a hook entry in
# hooks.json, update the EXPECTED triples below in the same change. That is
# the point of this file — it is a deliberate pin, not a coincidence.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOKS_JSON="$DIR/../hooks.json"
ROOT="$DIR/../.."

# 1. JSON validity
jq empty "$HOOKS_JSON" >/dev/null 2>&1
assert_exit "hooks.json is valid JSON" 0 "$?"

# 2. every referenced script path exists on disk
ARGS="$(jq -r '.. | .args? // empty | .[]' "$HOOKS_JSON")"
while IFS= read -r arg; do
  [ -z "$arg" ] && continue
  path="${arg/\$\{CLAUDE_PLUGIN_ROOT\}/$ROOT}"
  if [ -f "$path" ]; then
    HZ_PASS=$((HZ_PASS + 1))
  else
    HZ_FAIL=$((HZ_FAIL + 1))
    printf '  FAIL: script path missing: %s\n' "$path"
  fi
done <<EOF
$ARGS
EOF

# 3. the full (event, if-or-matcher, script basename) wiring, in one shot.
# SessionStart carries its condition as the entry-level "matcher" (no "if"
# on the hook itself); PreToolUse/PostToolUse carry it as "if" on each hook
# inside the entry's "hooks" array. Resolve both the same way jq sees them.
ACTUAL="$(jq -r '
  .hooks | to_entries[] as $ev |
  $ev.value[] as $entry |
  $entry.hooks[] |
  [$ev.key, (.if // $entry.matcher), (.args[0] | split("/") | last)] | join("|")
' "$HOOKS_JSON" | sort)"

EXPECTED='PostToolUse|Bash(git commit*)|post-commit.sh
PreToolUse|Bash(gh pr create*)|pre-pr-create.sh
PreToolUse|Bash(git checkout*)|pre-destructive.sh
PreToolUse|Bash(git clean*)|pre-destructive.sh
PreToolUse|Bash(git push*)|pre-push.sh
PreToolUse|Bash(git reset*)|pre-destructive.sh
PreToolUse|Bash(rm -*)|pre-destructive.sh
SessionStart|startup|session-context.sh'

assert_eq "hooks.json wiring matches the pinned expectation" "$EXPECTED" "$ACTUAL"

# 4. every command hook has a numeric timeout
TIMEOUTS="$(jq -r '[.. | objects | select(.type? == "command") | .timeout] | join(",")' "$HOOKS_JSON")"
BAD=0
IFS=',' read -ra T <<EOF
$TIMEOUTS
EOF
for t in "${T[@]}"; do
  case "$t" in
    ''|*[!0-9]*) BAD=1 ;;
  esac
done
assert_eq "every command hook has a numeric timeout" "0" "$BAD"

hz_test_summary
