#!/usr/bin/env bash
# Pi向け配布tarballを一時環境へ導入し、実際のPi RPC起動を確認する。
# ソース直読みでは見つからない梱包漏れと実行時依存の不整合をCIで防ぐために使う。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/hooks/tests/lib/harness.sh"

command -v npm >/dev/null 2>&1 || { echo "✘ test-pi-package.sh requires npm" >&2; exit 1; }

TMP="$(mktemp -d)"
cleanup() { rm -rf -- "$TMP"; }
trap cleanup EXIT

TARBALL_NAME="$(npm_config_cache="$TMP/npm-cache" npm pack --silent --pack-destination "$TMP")"
TARBALL="$TMP/$TARBALL_NAME"
RUNTIME="$TMP/runtime"
npm_config_cache="$TMP/npm-cache" npm install --prefix "$RUNTIME" --no-audit --no-fund --loglevel=error "$TARBALL"

PI_BIN="$RUNTIME/node_modules/.bin/pi"
PACKAGE_DIR="$RUNTIME/node_modules/hikizan"
[ -x "$PI_BIN" ]
assert_exit "packed package installs a Pi executable" 0 "$?"
[ -d "$PACKAGE_DIR" ]
assert_exit "packed hikizan package is installed" 0 "$?"
[ -f "$PACKAGE_DIR/hooks/adapters/pi/claude-agent-acp-read-only.js" ]
assert_exit "packed hikizan includes the read-only Claude ACP proxy" 0 "$?"

INSPECTOR="$TMP/tool-inspector.ts"
cat > "$INSPECTOR" <<'EOF'
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

PI_OUTPUT="$(printf '%s\n' '{"type":"get_commands"}' '{"type":"get_state"}' | \
  PI_CODING_AGENT_DIR="$TMP/pi-agent" HIKIZAN_SKIP_FETCH=1 \
  "$PI_BIN" --mode rpc --offline --no-session --approve -e "$PACKAGE_DIR" -e "$INSPECTOR" 2>&1)"
assert_contains "packed Pi registers /hikizan" '"name":"hikizan"' "$PI_OUTPUT"
assert_contains "packed Pi registers /shimon" '"name":"shimon"' "$PI_OUTPUT"
assert_contains "packed Pi registers /delegate" '"name":"delegate"' "$PI_OUTPUT"
assert_contains "packed Pi discovers hikizan skills" '"name":"skill:jikkou"' "$PI_OUTPUT"
while IFS= read -r name; do
  assert_contains "packed Pi registers /$name" "\"name\":\"$name\"" "$PI_OUTPUT"
done < <(jq -r '.core[]' "$ROOT/scripts/skills.json")
assert_contains "packed Pi registers shimon visual verification" 'PI_SHIMON_PRESENT' "$PI_OUTPUT"
assert_contains "packed Pi registers Claude delegation" 'PI_CLAUDE_DELEGATE_PRESENT' "$PI_OUTPUT"
assert_contains "packed Pi omits Exa without a key" 'PI_EXA_MISSING' "$PI_OUTPUT"

PI_EXA_OUTPUT="$(printf '%s\n' '{"type":"get_state"}' | \
  PI_CODING_AGENT_DIR="$TMP/pi-exa-agent" HIKIZAN_SKIP_FETCH=1 EXA_API_KEY=test-key \
  "$PI_BIN" --mode rpc --offline --no-session --approve -e "$PACKAGE_DIR" -e "$INSPECTOR" 2>&1)"
assert_contains "packed Pi keeps shimon with Exa configured" 'PI_SHIMON_PRESENT' "$PI_EXA_OUTPUT"
assert_contains "packed Pi registers Exa with a key" 'PI_EXA_PRESENT' "$PI_EXA_OUTPUT"

hz_test_summary
[ "$HZ_FAIL" -eq 0 ]
