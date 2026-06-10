#!/usr/bin/env bash
# E2E overhead benchmark (Phase 4-1): does the hikizan harness slow a strong
# model down? Runs `claude -p --output-format json` with and without the plugin
# across 3 scenarios and reports turns + output tokens + the overhead ratio.
#
# USER-RUN. It spawns real headless claude sessions — costs tokens and needs an
# authenticated CLI. NOT part of `hooks/tests/run.sh` / CI.
#
#   bash hooks/tests/e2e/bench.sh            # full benchmark
#   bash hooks/tests/e2e/bench.sh --dry      # wiring check only (no claude call)
#
# Acceptance (from the refactor plan):
#   - standard-tier 小修正 overhead < +15% output tokens vs no-plugin baseline
#   - hook firing counts in ~/.hikizan/metrics.jsonl are consistent across runs

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DRY=0; [ "${1:-}" = "--dry" ] && DRY=1

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found — install Claude Code to run the benchmark"; exit 1
fi

# A throwaway repo so edit/submit scenarios have something to act on.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
git -C "$SANDBOX" init -q
git -C "$SANDBOX" config user.email b@example.com
git -C "$SANDBOX" config user.name bench
printf 'export const VERSION = "0.0.0";\n' > "$SANDBOX/version.ts"
git -C "$SANDBOX" add -A && git -C "$SANDBOX" commit -q -m init

# scenario prompts (kept read-mostly so a bare run is cheap and safe)
P_SMALL='version.ts の VERSION を 0.0.1 に上げる最小の修正方針だけを 3 行以内で答えて。実装はしない。'
P_SUBMIT='この変更を PR に出す手順の要点だけを列挙して。実際の push や gh は実行しない。'

run_one() { # <label> <on|off> <tier> <prompt> ; prints "label turns otok"
  local label="$1" mode="$2" tier="$3" prompt="$4" out turns otok
  if [ "$DRY" -eq 1 ]; then
    printf '%s DRY (would run: plugin=%s tier=%s)\n' "$label" "$mode" "$tier"
    return 0
  fi
  if [ "$mode" = "on" ]; then
    out=$(cd "$SANDBOX" && HIKIZAN_TIER="$tier" claude -p "$prompt" \
            --output-format json --plugin-dir "$ROOT" 2>/dev/null)
  else
    out=$(cd "$SANDBOX" && claude -p "$prompt" --output-format json 2>/dev/null)
  fi
  turns=$(printf '%s' "$out" | jq -r '.num_turns // 0' 2>/dev/null)
  otok=$(printf '%s' "$out" | jq -r '(.usage.output_tokens // .usage.outputTokens // 0)' 2>/dev/null)
  printf '%s %s %s\n' "$label" "${turns:-0}" "${otok:-0}"
}

echo "=== hikizan E2E overhead benchmark ==="
echo "root: $ROOT   sandbox: $SANDBOX   dry: $DRY"
echo

# 1. small fix — baseline vs plugin(standard)
B=$(run_one small-baseline       off standard "$P_SMALL")
S=$(run_one small-plugin-standard on standard "$P_SMALL")
# 2. submit flow — plugin(standard)
M=$(run_one submit-plugin-standard on standard "$P_SUBMIT")
# 3. guided tier — small fix
G=$(run_one small-plugin-guided  on guided   "$P_SMALL")

printf '%s\n%s\n%s\n%s\n' "$B" "$S" "$M" "$G"

if [ "$DRY" -eq 0 ]; then
  bt=$(printf '%s' "$B" | awk '{print $3}')
  st=$(printf '%s' "$S" | awk '{print $3}')
  if [ "${bt:-0}" -gt 0 ] 2>/dev/null; then
    pct=$(awk -v b="$bt" -v s="$st" 'BEGIN{ printf "%.1f", (s-b)/b*100 }')
    echo
    echo "small-fix output-token overhead: ${pct}%  (acceptance: < 15%)"
  fi
  echo "hook firings this run:"
  jq -r 'select(.event=="hook_fired") | .hook' "${HIKIZAN_METRICS_DIR:-$HOME/.hikizan}/metrics.jsonl" 2>/dev/null \
    | sort | uniq -c || true
fi
