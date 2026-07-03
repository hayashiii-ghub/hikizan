#!/usr/bin/env bash
# Generate the Cursor and Codex plugin manifests from the Claude Code manifest
# (.claude-plugin/plugin.json = single source for version/author). The
# harness-specific fields (description / keywords / component pointers) live
# here. Do not edit .cursor-plugin/plugin.json or .codex-plugin/plugin.json by
# hand — rerun this script instead.
#   bash scripts/gen-manifests.sh           # write both manifests
#   bash scripts/gen-manifests.sh --check   # fail if regen would change them
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "✘ gen-manifests.sh requires jq" >&2; exit 1; }
SRC="$ROOT/.claude-plugin/plugin.json"
ver="$(jq -r .version "$SRC")"
author="$(jq -c .author "$SRC")"

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
    description: "hikizan for Codex: bundles the verb skills (tansaku / sadoku / sekkei / jikkou / teishutsu / kaku), the PreToolUse floors (force-push deny, destructive-op ask, non-draft PR deny) reusing the Claude Code hook scripts verbatim, and the routing conventions + standard-tier opt-out preamble via the SessionStart hook.",
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
  check_one "$ROOT/.cursor-plugin/plugin.json" gen_cursor || rc=1
  check_one "$ROOT/.codex-plugin/plugin.json" gen_codex || rc=1
  exit "$rc"
else
  mkdir -p "$ROOT/.cursor-plugin" "$ROOT/.codex-plugin"
  gen_cursor > "$ROOT/.cursor-plugin/plugin.json"
  gen_codex > "$ROOT/.codex-plugin/plugin.json"
  echo "✔ wrote .cursor-plugin/plugin.json and .codex-plugin/plugin.json"
fi
