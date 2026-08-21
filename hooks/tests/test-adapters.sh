#!/usr/bin/env bash
# CodexとCursorの起動情報の配線を確認する。
# ハーネス固有の設定へシェル実行前の判定が戻らないようにするために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
ROOT="$DIR/../.."

CODEX="$ROOT/hooks/adapters/codex/hooks.json"
jq empty "$CODEX" >/dev/null 2>&1
assert_exit "Codex hooks JSON is valid" 0 "$?"
assert_eq "Codex exposes only SessionStart" '["SessionStart"]' \
  "$(jq -c '.hooks | keys' "$CODEX")"

CURSOR="$ROOT/hooks/adapters/cursor/hooks.json"
jq empty "$CURSOR" >/dev/null 2>&1
assert_exit "Cursor hooks JSON is valid" 0 "$?"
assert_eq "Cursor exposes only sessionStart" '["sessionStart"]' \
  "$(jq -c '.hooks | keys' "$CURSOR")"

PI_PACKAGE="$ROOT/package.json"
jq empty "$PI_PACKAGE" >/dev/null 2>&1
assert_exit "pi package JSON is valid" 0 "$?"
assert_eq "pi package exposes the portable skills" '["./skills"]' \
  "$(jq -c '.pi.skills' "$PI_PACKAGE")"
assert_eq "pi package exposes only the pi adapter" '["./hooks/adapters/pi/index.ts"]' \
  "$(jq -c '.pi.extensions' "$PI_PACKAGE")"
assert_eq "pi package declares its bundled core API as a peer" '"*"' \
  "$(jq -c '.peerDependencies["@earendil-works/pi-coding-agent"]' "$PI_PACKAGE")"
assert_eq "pi package declares its bundled TUI API as a peer" '"*"' \
  "$(jq -c '.peerDependencies["@earendil-works/pi-tui"]' "$PI_PACKAGE")"
assert_eq "pi package declares TypeBox as a peer" '"*"' \
  "$(jq -c '.peerDependencies.typebox' "$PI_PACKAGE")"
assert_eq "pi package installs shimon visual verification" '"^0.3.1"' \
  "$(jq -c '.dependencies["@hayashiii/shimon"]' "$PI_PACKAGE")"
assert_eq "pi package installs the ACP client" '"0.13.1"' \
  "$(jq -c '.dependencies.acpx' "$PI_PACKAGE")"
assert_eq "pi package installs the Claude ACP agent" '"0.65.0"' \
  "$(jq -c '.dependencies["@agentclientprotocol/claude-agent-acp"]' "$PI_PACKAGE")"

PI_ADAPTER="$ROOT/hooks/adapters/pi/index.ts"
[ -f "$PI_ADAPTER" ]
assert_exit "pi adapter exists" 0 "$?"
assert_contains "pi adapter loads shared session routing" 'SESSION_ROUTING, "pi"' \
  "$(cat "$PI_ADAPTER")"
assert_contains "pi adapter registers its TUI command" 'registerCommand("hikizan"' \
  "$(cat "$PI_ADAPTER")"
assert_contains "pi adapter renders the hikizan ASCII wordmark" '/___/\\__,_/_/ /_/' \
  "$(cat "$PI_ADAPTER")"
assert_contains "pi adapter keeps a narrow fallback" 'if (width < 38) return ["", "  hikizan", ""]' \
  "$(cat "$PI_ADAPTER")"
assert_contains "pi adapter registers the complete shimon extension" 'shimonForPi(pi)' \
  "$(cat "$PI_ADAPTER")"
assert_contains "pi adapter conditionally registers Exa search" 'registerExaSearchIfConfigured(pi)' \
  "$(cat "$PI_ADAPTER")"
assert_contains "pi adapter registers its production guard" 'registerProductionGuard(pi)' \
  "$(cat "$PI_ADAPTER")"
assert_contains "pi adapter registers Claude delegation" 'registerClaudeDelegate(pi)' \
  "$(cat "$PI_ADAPTER")"

EXA_SEARCH="$ROOT/hooks/adapters/pi/exa-search.ts"
EXA_CLIENT="$ROOT/hooks/adapters/pi/exa-client.js"
[ -f "$EXA_SEARCH" ]
assert_exit "pi Exa tool exists" 0 "$?"
[ -f "$EXA_CLIENT" ]
assert_exit "pi Exa client exists" 0 "$?"
assert_contains "pi Exa tool gates registration on its API key" 'if (!apiKey) return false' \
  "$(cat "$EXA_SEARCH")"
assert_contains "pi Exa client uses the low-latency search type" 'type: "fast"' \
  "$(cat "$EXA_CLIENT")"

if command -v pi >/dev/null 2>&1 && [ -d "$ROOT/node_modules/@hayashiii/shimon" ]; then
  PI_AGENT_DIR=$(mktemp -d)
  PI_INSPECTOR="$PI_AGENT_DIR/tool-inspector.ts"
  cat > "$PI_INSPECTOR" <<'EOF'
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function inspectPiTools(pi: ExtensionAPI): void {
  pi.on("session_start", async () => {
    const tools = pi.getAllTools();
    process.stderr.write(tools.some((tool) => tool.name === "shimon_verify") ? "PI_SHIMON_PRESENT\n" : "PI_SHIMON_MISSING\n");
    process.stderr.write(tools.some((tool) => tool.name === "web_search") ? "PI_EXA_PRESENT\n" : "PI_EXA_MISSING\n");
    process.stderr.write(tools.some((tool) => tool.name === "delegate_claude") ? "PI_CLAUDE_DELEGATE_PRESENT\n" : "PI_CLAUDE_DELEGATE_MISSING\n");
  });
}
EOF
  PI_OUTPUT=$(printf '%s\n' '{"type":"get_commands"}' '{"type":"get_state"}' | \
    PI_CODING_AGENT_DIR="$PI_AGENT_DIR" HIKIZAN_SKIP_FETCH=1 \
    pi --mode rpc --offline --no-session --approve -e "$ROOT" -e "$PI_INSPECTOR" 2>&1)
  assert_contains "pi loads the hikizan extension" '"name":"hikizan"' "$PI_OUTPUT"
  assert_contains "pi registers the shimon command" '"name":"shimon"' "$PI_OUTPUT"
  assert_contains "pi registers the delegate command" '"name":"delegate"' "$PI_OUTPUT"
  assert_contains "pi discovers the hikizan skills" '"name":"skill:jikkou"' "$PI_OUTPUT"
  assert_contains "pi registers shimon visual verification" 'PI_SHIMON_PRESENT' "$PI_OUTPUT"
  assert_contains "pi registers Claude ACP delegation" 'PI_CLAUDE_DELEGATE_PRESENT' "$PI_OUTPUT"
  assert_contains "pi omits Exa search without a key" 'PI_EXA_MISSING' "$PI_OUTPUT"

  PI_EXA_OUTPUT=$(printf '%s\n' '{"type":"get_state"}' | \
    PI_CODING_AGENT_DIR="$PI_AGENT_DIR" HIKIZAN_SKIP_FETCH=1 EXA_API_KEY=test-key \
    pi --mode rpc --offline --no-session --approve -e "$ROOT" -e "$PI_INSPECTOR" 2>&1)
  assert_contains "pi keeps shimon when Exa is configured" 'PI_SHIMON_PRESENT' "$PI_EXA_OUTPUT"
  assert_contains "pi registers Exa search when a key is present" 'PI_EXA_PRESENT' "$PI_EXA_OUTPUT"
  rm -rf "$PI_AGENT_DIR"
else
  printf '  skip: pi runtime smoke test (pi or installed package dependencies are unavailable)\n'
fi

hz_test_summary
