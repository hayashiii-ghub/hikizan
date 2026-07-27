#!/usr/bin/env bash
# Claude CodeのHook設定とイベント配線を確認する。
# 起動情報以外の責務が混ざらないようにするために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOKS_JSON="$DIR/../hooks.json"
ROOT="$DIR/../.."

jq empty "$HOOKS_JSON" >/dev/null 2>&1
assert_exit "hooks.json is valid JSON" 0 "$?"

ARGS=$(jq -r '.. | .args? // empty | .[]' "$HOOKS_JSON")
while IFS= read -r arg; do
  case "$arg" in
    *'${CLAUDE_PLUGIN_ROOT}'*)
      path="${arg/\$\{CLAUDE_PLUGIN_ROOT\}/$ROOT}"
      if [ -f "$path" ]; then HZ_PASS=$((HZ_PASS + 1)); else
        HZ_FAIL=$((HZ_FAIL + 1)); printf '  FAIL: script path missing: %s\n' "$path"
      fi
      ;;
  esac
done <<EOF
$ARGS
EOF

ACTUAL=$(jq -r '
  .hooks | to_entries[] as $event |
  $event.value[] as $entry |
  $entry.hooks[] |
  [$event.key, $entry.matcher, (.args[0] | split("/") | last)] | join("|")
' "$HOOKS_JSON" | sort)
EXPECTED='SessionStart|startup|session-routing.sh'
assert_eq "Claude wiring has only session context" "$EXPECTED" "$ACTUAL"

TIMEOUTS=$(jq -r '[.. | objects | select(.type? == "command") | .timeout] | join(",")' "$HOOKS_JSON")
assert_eq "session hook uses a ten-second harness timeout" "10" "$TIMEOUTS"

hz_test_summary
