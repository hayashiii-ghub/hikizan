#!/usr/bin/env bash
# Generate all three plugin manifests from plugin.src.json (the single
# hand-edited source for version / author / description). The harness-specific
# fields for Cursor and Codex (description / keywords / component pointers)
# live here. Do not edit .claude-plugin/plugin.json, .cursor-plugin/plugin.json
# or .codex-plugin/plugin.json by hand — edit plugin.src.json and rerun.
#   bash scripts/gen-manifests.sh           # write the manifests
#   bash scripts/gen-manifests.sh --check   # fail if regen would change them
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "✘ gen-manifests.sh requires jq" >&2; exit 1; }
SRC="$ROOT/plugin.src.json"
[ -f "$SRC" ] || { echo "✘ missing plugin.src.json" >&2; exit 1; }
ver="$(jq -r .version "$SRC")"
author="$(jq -c .author "$SRC")"

gen_claude() { cat "$SRC"; }

gen_cursor() {
  jq -n --arg v "$ver" --argjson a "$author" '{
    name: "hikizan",
    version: $v,
    description: "hikizan floors + routing/opt-out for Cursor: beforeShellExecution blocks force-push to protected branches, destructive ops, and non-draft PRs; an always-apply rule injects the routing conventions and the standard-tier opt-out preamble.",
    author: $a,
    keywords: ["floors", "hooks", "code-review", "workflow", "japanese"],
    rules: "cursor/rules/",
    hooks: "cursor/hooks.json"
  }'
}

gen_codex() {
  jq -n --arg v "$ver" --argjson a "$author" '{
    name: "hikizan",
    version: $v,
    description: "hikizan for Codex: bundles the verb skills (tansaku / sadoku / sekkei / jikkou / teishutsu / shippitsu), the PreToolUse floors (force-push deny, destructive-op ask, non-draft PR deny) reusing the Claude Code hook scripts verbatim, and the routing conventions + standard-tier opt-out preamble via the SessionStart hook.",
    author: $a,
    keywords: ["skills", "floors", "hooks", "code-review", "workflow", "japanese"],
    skills: "./skills/",
    hooks: "./codex/hooks.json"
  }'
}

check_one() {
  local path="$1" genfn="$2"
  if diff -q "$path" <("$genfn") >/dev/null 2>&1; then
    echo "✔ ${path#$ROOT/} up to date"
  else
    echo "✘ ${path#$ROOT/} is stale — run: bash scripts/gen-manifests.sh" >&2
    return 1
  fi
}

if [ "${1:-}" = "--check" ]; then
  rc=0
  check_one "$ROOT/.claude-plugin/plugin.json" gen_claude || rc=1
  check_one "$ROOT/.cursor-plugin/plugin.json" gen_cursor || rc=1
  check_one "$ROOT/.codex-plugin/plugin.json" gen_codex || rc=1
  exit "$rc"
else
  mkdir -p "$ROOT/.claude-plugin" "$ROOT/.cursor-plugin" "$ROOT/.codex-plugin"
  gen_claude > "$ROOT/.claude-plugin/plugin.json"
  gen_cursor > "$ROOT/.cursor-plugin/plugin.json"
  gen_codex > "$ROOT/.codex-plugin/plugin.json"
  echo "✔ wrote .claude-plugin/plugin.json, .cursor-plugin/plugin.json and .codex-plugin/plugin.json"
fi
