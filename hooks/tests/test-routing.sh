#!/usr/bin/env bash
# 共通ルーティングの生成と、各ハーネスへの配布形式を固定する。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."
ROUTING="$ROOT/hooks/routing.md"
SESSION_ROUTING="$ROOT/hooks/scripts/session-routing.sh"

bash "$ROOT/scripts/gen-routing.sh" --check >/dev/null 2>&1
assert_exit "routing artifacts are current" 0 "$?"

EXPECTED="$(cat "$ROUTING")"
ACTUAL="$(bash "$SESSION_ROUTING" claude)"
assert_eq "Claude receives the shared routing text" "$EXPECTED" "$ACTUAL"

CODEX="$(bash "$SESSION_ROUTING" codex)"
assert_eq "Codex SessionStart event is named correctly" "SessionStart" \
  "$(printf '%s' "$CODEX" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "Codex receives the shared routing text" "$EXPECTED" \
  "$(printf '%s' "$CODEX" | jq -r '.hookSpecificOutput.additionalContext')"

assert_contains "Cursor rule is always applied" "alwaysApply: true" \
  "$(cat "$ROOT/hooks/adapters/cursor/rules/hikizan.mdc")"
assert_eq "Cursor manifest publishes the routing rule" "hooks/adapters/cursor/rules/" \
  "$(jq -r '.rules' "$ROOT/.cursor-plugin/plugin.json")"

CLAUDE_EVENTS="$(jq -r '.hooks | keys[]' "$ROOT/hooks/hooks.json" | sort | tr '\n' ' ')"
assert_contains "Claude registers SessionStart routing" "SessionStart" "$CLAUDE_EVENTS"
CODEX_EVENTS="$(jq -r '.hooks | keys[]' "$ROOT/hooks/adapters/codex/hooks.json" | sort | tr '\n' ' ')"
assert_contains "Codex registers SessionStart routing" "SessionStart" "$CODEX_EVENTS"

SKILLS="$(jq -r '.core[]' "$ROOT/scripts/skills.json")"
while IFS= read -r skill; do
  assert_contains "routing includes $skill" "\`$skill\`" "$EXPECTED"
done <<EOF
$SKILLS
EOF

hz_test_summary
