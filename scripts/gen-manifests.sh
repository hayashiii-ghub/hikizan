#!/usr/bin/env bash
# plugin.src.jsonからAgent PluginsとClaude Code、Cursor、Codexのマニフェストを生成する。
# バージョンと基本情報を一度の編集で共通規格と3ハーネスへ揃えるために使う。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "✘ gen-manifests.sh requires jq" >&2; exit 1; }
SRC="$ROOT/plugin.src.json"
[ -f "$SRC" ] || { echo "✘ missing plugin.src.json" >&2; exit 1; }
jq -e '
  (.name | type == "string" and length > 0) and
  (.version | type == "string" and length > 0) and
  (.author | type == "object") and
  (.author.name | type == "string" and length > 0) and
  (.homepage | type == "string" and length > 0) and
  (.repository | type == "string" and length > 0) and
  (.license | type == "string" and length > 0) and
  (.keywords | type == "array" and length > 0) and
  all(.keywords[]; type == "string" and length > 0) and
  (has("$schema") | not) and
  (has("description") | not) and
  (.descriptions | type == "object") and
  all(.descriptions.portable, .descriptions.claude, .descriptions.cursor, .descriptions.codex;
    type == "string" and length > 0 and contains("{{core_skills}}")) and
  (.codexInterface.shortDescription | type == "string" and length > 0) and
  (.codexInterface.longDescription | type == "string" and length > 0) and
  (.codexInterface.category | type == "string" and length > 0) and
  (.codexInterface.capabilities | type == "array" and length > 0) and
  all(.codexInterface.capabilities[]; type == "string" and length > 0)
' "$SRC" >/dev/null || { echo "✘ plugin.src.json metadata is incomplete" >&2; exit 1; }
name="$(jq -r .name "$SRC")"
ver="$(jq -r .version "$SRC")"
author="$(jq -c .author "$SRC")"
homepage="$(jq -r .homepage "$SRC")"
repository="$(jq -r .repository "$SRC")"
license="$(jq -r .license "$SRC")"
keywords="$(jq -c .keywords "$SRC")"
codex_interface="$(jq -c .codexInterface "$SRC")"
skill_list="$(jq -r '.core | join(" / ")' "$ROOT/scripts/skills.json")"
[ -n "$skill_list" ] || { echo "✘ failed to read core skills from scripts/skills.json" >&2; exit 1; }

render_description() {
  local harness="$1"
  jq -er --arg harness "$harness" --arg skills "$skill_list" '
    .descriptions[$harness]
    | gsub("\\{\\{core_skills\\}\\}"; $skills)
    | if (contains("{{") or contains("}}"))
      then error("unresolved description placeholder for " + $harness)
      else .
      end
  ' "$SRC"
}

claude_description="$(render_description claude)"
cursor_description="$(render_description cursor)"
codex_description="$(render_description codex)"
portable_description="$(render_description portable)"

gen_portable() {
  jq -n --arg name "$name" --arg description "$portable_description" \
    --arg v "$ver" --argjson a "$author" --arg homepage "$homepage" \
    --arg repository "$repository" --arg license "$license" \
    --argjson keywords "$keywords" '{
    "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
    name: $name,
    version: $v,
    description: $description,
    author: $a,
    homepage: $homepage,
    repository: $repository,
    license: $license,
    keywords: $keywords
  }'
}

gen_claude() {
  jq -n --arg name "$name" --arg description "$claude_description" \
    --arg v "$ver" --argjson a "$author" --arg homepage "$homepage" \
    --arg repository "$repository" --arg license "$license" \
    --argjson keywords "$keywords" '{
    "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
    name: $name,
    description: $description,
    version: $v,
    author: $a,
    homepage: $homepage,
    repository: $repository,
    license: $license,
    keywords: $keywords
  }'
}

gen_cursor() {
  jq -n --arg name "$name" --arg v "$ver" --argjson a "$author" \
    --arg description "$cursor_description" \
    --arg homepage "$homepage" --arg repository "$repository" --arg license "$license" \
    --argjson keywords "$keywords" '{
    name: $name,
    version: $v,
    description: $description,
    author: $a,
    homepage: $homepage,
    repository: $repository,
    license: $license,
    keywords: $keywords,
    rules: "hooks/adapters/cursor/rules/",
    hooks: "hooks/adapters/cursor/hooks.json"
  }'
}

gen_codex() {
  jq -n --arg name "$name" --arg v "$ver" --argjson a "$author" \
    --arg description "$codex_description" \
    --argjson interface "$codex_interface" \
    --arg homepage "$homepage" --arg repository "$repository" --arg license "$license" \
    --argjson keywords "$keywords" '{
    name: $name,
    version: $v,
    description: $description,
    author: $a,
    homepage: $homepage,
    repository: $repository,
    license: $license,
    interface: {
      displayName: $name,
      shortDescription: $interface.shortDescription,
      longDescription: $interface.longDescription,
      developerName: $a.name,
      category: $interface.category,
      capabilities: $interface.capabilities
    },
    keywords: $keywords,
    skills: "./skills/",
    hooks: "./hooks/adapters/codex/hooks.json"
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
  check_one "$ROOT/plugin.json" gen_portable || rc=1
  check_one "$ROOT/.claude-plugin/plugin.json" gen_claude || rc=1
  check_one "$ROOT/.cursor-plugin/plugin.json" gen_cursor || rc=1
  check_one "$ROOT/.codex-plugin/plugin.json" gen_codex || rc=1
  exit "$rc"
else
  mkdir -p "$ROOT/.claude-plugin" "$ROOT/.cursor-plugin" "$ROOT/.codex-plugin"
  tmp_portable="$(mktemp "$ROOT/plugin.json.tmp.XXXXXX")"
  tmp_claude="$(mktemp "$ROOT/.claude-plugin/plugin.json.tmp.XXXXXX")"
  tmp_cursor="$(mktemp "$ROOT/.cursor-plugin/plugin.json.tmp.XXXXXX")"
  tmp_codex="$(mktemp "$ROOT/.codex-plugin/plugin.json.tmp.XXXXXX")"
  cleanup() {
    [ -z "${tmp_portable:-}" ] || rm -f -- "$tmp_portable"
    [ -z "${tmp_claude:-}" ] || rm -f -- "$tmp_claude"
    [ -z "${tmp_cursor:-}" ] || rm -f -- "$tmp_cursor"
    [ -z "${tmp_codex:-}" ] || rm -f -- "$tmp_codex"
  }
  trap cleanup EXIT
  gen_portable > "$tmp_portable"
  gen_claude > "$tmp_claude"
  gen_cursor > "$tmp_cursor"
  gen_codex > "$tmp_codex"
  jq -e . "$tmp_portable" "$tmp_claude" "$tmp_cursor" "$tmp_codex" >/dev/null
  chmod 0644 "$tmp_portable"
  chmod 0644 "$tmp_claude" "$tmp_cursor" "$tmp_codex"
  mv "$tmp_portable" "$ROOT/plugin.json"
  mv "$tmp_claude" "$ROOT/.claude-plugin/plugin.json"
  mv "$tmp_cursor" "$ROOT/.cursor-plugin/plugin.json"
  mv "$tmp_codex" "$ROOT/.codex-plugin/plugin.json"
  tmp_portable=""
  tmp_claude=""
  tmp_cursor=""
  tmp_codex=""
  trap - EXIT
  echo "✔ wrote plugin.json, .claude-plugin/plugin.json, .cursor-plugin/plugin.json and .codex-plugin/plugin.json"
fi
