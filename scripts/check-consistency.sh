#!/usr/bin/env bash
# 生成処理だけでは確認できない、ファイル間の構造と規約のずれを検査する。
# 配布物の欠落やハーネス間の不整合を公開前に見つけるために使う。
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$(jq -r '.core | join(" ")' "$ROOT/scripts/skills.json")"
[ -n "$CORE" ] || { echo "✘ failed to read core skills"; exit 1; }
fail=0

ok() { printf '✔ %s\n' "$1"; }
bad() { printf '✘ %s\n' "$1"; fail=1; }
require_text() { grep -qF -- "$2" "$1" || bad "$3"; }
forbid_text() { grep -qF -- "$2" "$1" && bad "$3"; return 0; }

# 公開する実装直下だけを調べ、無関係な隠しディレクトリを走査しない。
roots="$(find "$ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -exec basename {} \; | sort | tr '\n' ' ' | sed 's/ $//')"
[ "$roots" = "hooks scripts skills" ] && ok "non-hidden implementation roots are hooks / scripts / skills" || bad "unexpected non-hidden root directories: $roots"

# skills.json is the exact discovery set.
actual="$(find "$ROOT/skills" -mindepth 2 -type f | sed "s#^$ROOT/skills/##" | awk -F/ '{print $1}' | sort -u | tr '\n' ' ' | sed 's/ $//')"
expected="$(printf '%s\n' $CORE | sort | tr '\n' ' ' | sed 's/ $//')"
[ "$actual" = "$expected" ] && ok "skills directory matches scripts/skills.json" || bad "skill set drift: expected [$expected], actual [$actual]"
for name in $CORE; do
  frontmatter_name="$(awk -F': *' '/^name:/ { print $2; exit }' "$ROOT/skills/$name/SKILL.md")"
  [ "$frontmatter_name" = "$name" ] || bad "skill discovery name mismatch: directory=$name frontmatter=$frontmatter_name"
  description="$(awk '/^description:/ { sub(/^description:[[:space:]]*/, ""); print; exit }' "$ROOT/skills/$name/SKILL.md")"
  [ -n "$description" ] || bad "skill description is empty: $name"
  ! grep -q '^when_to_use:' "$ROOT/skills/$name/SKILL.md" || bad "duplicate when_to_use remains: $name"
done
require_text "$ROOT/scripts/contract.md" '🌲 <スキル名>（日本語名）：<今回の目的>' "shared contract omits the skill activation marker"
require_text "$ROOT/scripts/contract.md" '調査、相談、設計、レビューだけの依頼では対象を変更しない' "shared contract omits the read-only boundary"
require_text "$ROOT/scripts/contract.md" '最大3件を推奨順に`A（あ）`、`I（い）`、`U（う）`で示す' "shared contract omits bilingual handoff choices"
require_text "$ROOT/scripts/contract.md" 'PRのマージと既定ブランチへの直接のpush、公開・配布・本番環境や共有データを変更する操作は、利用者が依頼の終点として明示した場合だけ行う' "shared contract omits the external-change authority boundary"
require_text "$ROOT/AGENTS.md" 'packed artifactを一時環境へ導入し、実際のpi起動' "AGENTS does not require packed Pi startup verification"
require_text "$ROOT/hooks/conditions.md" '`delegate_claude`' "hook responsibilities omit Claude delegation registration"


# 各スキルはSKILL.mdだけで完結する。
for name in $CORE; do
  extra="$(find "$ROOT/skills/$name" -type f ! -name SKILL.md -print)"
  [ -z "$extra" ] || bad "unexpected skill files: $extra"
  forbid_text "$ROOT/skills/$name/SKILL.md" 'references/' "skill depends on removed reference files: $name"
done

# Paths stay ASCII for tools; human-facing Markdown headings stay Japanese.
heading_drift="$({ find "$ROOT" -maxdepth 1 -type f -name '*.md' -print0; find "$ROOT/skills" "$ROOT/hooks" "$ROOT/scripts" -type f -name '*.md' -print0; } | while IFS= read -r -d '' file; do
  awk 'BEGIN { code=0 } /^```/ { code=!code; next } !code && /^#{1,3}[[:space:]]/ && $0 !~ /[ぁ-んァ-ヶ一-龠]/ { print FNR ":" $0 }' "$file" |
    while IFS= read -r line; do printf '%s:%s\n' "${file#$ROOT/}" "$line"; done
done)"
if [ -n "$heading_drift" ]; then
  printf '%s\n' "$heading_drift"
  bad "human-facing Markdown contains a non-Japanese heading"
else
  ok "human-facing Markdown headings are Japanese"
fi

# Generated manifests share one version and retain the native entrypoints.
portable_ver="$(jq -r .version "$ROOT/plugin.json")"
cc_ver="$(jq -r .version "$ROOT/.claude-plugin/plugin.json")"
cur_ver="$(jq -r .version "$ROOT/.cursor-plugin/plugin.json")"
cx_ver="$(jq -r .version "$ROOT/.codex-plugin/plugin.json")"
pi_ver="$(jq -r .version "$ROOT/package.json")"
[ "$portable_ver" = "$cc_ver" ] && [ "$cc_ver" = "$cur_ver" ] && [ "$cc_ver" = "$cx_ver" ] && [ "$cc_ver" = "$pi_ver" ] && ok "plugin manifest versions match ($cc_ver)" || bad "plugin manifest versions drift"
jq -e '
  ."$schema" == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json" and
  .name == "hikizan" and
  (keys - ["$schema", "name", "version", "description", "author", "homepage", "repository", "license", "keywords"] | length == 0)
' "$ROOT/plugin.json" >/dev/null || bad "root plugin.json does not conform to the portable manifest surface"
jq -e '.rules == "hooks/adapters/cursor/rules/" and (has("hooks") | not)' "$ROOT/.cursor-plugin/plugin.json" >/dev/null || bad "Cursor manifest does not publish rules without a startup hook"
jq -e '.hooks == "./hooks/adapters/codex/hooks.json" and (has("skills") | not)' "$ROOT/.codex-plugin/plugin.json" >/dev/null || bad "Codex manifest does not keep portable skills separate from the slim adapter"
jq -e '
  .name == "hikizan" and
  (.keywords | index("pi-package") != null) and
  .peerDependencies == {
    "@earendil-works/pi-coding-agent": "*",
    "@earendil-works/pi-tui": "*",
    "typebox": "*"
  } and
  .dependencies == {
    "@agentclientprotocol/claude-agent-acp": "0.65.0",
    "@hayashiii/shimon": "^0.3.1",
    "acpx": "0.13.1",
    "pi-rewind": "github:hayashiii-ghub/pi-rewind#c34c2a89436ddef69661bee8fa84ea6067f386c3"
  } and
  .pi.skills == ["./skills"] and
  .pi.extensions == ["./hooks/adapters/pi/index.ts"]
' "$ROOT/package.json" >/dev/null || bad "pi package does not publish the skills and slim adapter"

# Claude and Codex retain startup routing; Cursor uses rules and pi uses native skill discovery.
jq -e '.hooks | keys == ["SessionStart"]' "$ROOT/hooks/hooks.json" >/dev/null || bad "Claude hook surface is not startup-only"
jq -e '.hooks | keys == ["SessionStart"]' "$ROOT/hooks/adapters/codex/hooks.json" >/dev/null || bad "Codex hook surface is not startup-only"
require_text "$ROOT/hooks/hooks.json" 'session-routing.sh' "Claude does not load shared skill routing"
require_text "$ROOT/hooks/adapters/codex/hooks.json" 'session-routing.sh codex' "Codex does not load shared skill routing"
require_text "$ROOT/hooks/adapters/cursor/rules/hikizan.mdc" 'alwaysApply: true' "Cursor routing rule is not always applied"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'pi.on("session_start"' "pi does not load startup information"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'ctx.ui.setHeader' "pi does not expose the hikizan TUI header"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'shimonForPi(pi)' "pi does not expose the complete shimon extension"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'rewindForPi(pi)' "pi does not expose safe rewind"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'registerExaSearchIfConfigured(pi)' "pi does not expose optional Exa search"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'registerProductionGuard(pi)' "pi does not register the production guard"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'registerClaudeDelegate(pi)' "pi does not register Claude ACP delegation"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'registerSkillAliases(pi)' "pi does not register direct skill aliases"
require_text "$ROOT/hooks/adapters/pi/exa-search.ts" 'if (!apiKey) return false' "pi Exa search is not gated by EXA_API_KEY"
require_text "$ROOT/hooks/adapters/pi/exa-client.js" 'type: "fast"' "pi Exa client does not use low-latency search"
require_text "$ROOT/hooks/adapters/pi/exa-client.js" 'case 402:' "pi Exa client does not stop on exhausted credit"
for symbol in 🌲 🌿 🔭 🧭 🛠️ 👀 🚀 ✍️; do
  forbid_text "$ROOT/hooks/adapters/pi/index.ts" "$symbol" "pi TUI embeds an emoji: $symbol"
done
[ -x "$ROOT/hooks/scripts/session-routing.sh" ] || bad "session routing adapter is not executable"
for file in "$ROOT/hooks/hooks.json" "$ROOT/hooks/adapters/codex/hooks.json"; do
  jq empty "$file" >/dev/null 2>&1 || bad "invalid JSON: ${file#$ROOT/}"
done

# Removed subsystems must not return through a generated or copied surface.
legacy=0
for path in agents codex context cursor docs opencode .claude/agents .cursor/agents .codex/agents skills/init hooks/scripts/session-context.sh hooks/scripts/post-command.sh hooks/scripts/lib/metrics.sh hooks/scripts/pre-push.sh hooks/scripts/pre-pr-create.sh hooks/scripts/pre-destructive.sh hooks/scripts/lib/push-parse.sh hooks/scripts/lib/pr-create.sh hooks/scripts/lib/destructive.sh; do
  if [ -d "$ROOT/$path" ]; then
    [ -z "$(find "$ROOT/$path" -type f -print -quit)" ] || { printf '✘ removed surface returned: %s\n' "$path"; legacy=1; }
  else
    [ ! -e "$ROOT/$path" ] || { printf '✘ removed surface returned: %s\n' "$path"; legacy=1; }
  fi
done
[ "$legacy" -eq 0 ] && ok "legacy tiers, metrics, adapter, and duplicate-doc surfaces stay removed" || fail=1

# Skills are installed as one pack; cross-skill references use logical names.
require_text "$ROOT/AGENTS.md" 'パック単位' "AGENTS is missing the pack-only boundary"
skill_alt="$(jq -r '.core | join("|")' "$ROOT/scripts/skills.json")"
if grep -R -nE "skills/($skill_alt)/|(\.\./)+($skill_alt)/" "$ROOT/skills"; then
  bad "runtime skill content contains repository-relative cross-skill references"
else
  ok "runtime cross-skill references use logical names"
fi

# Distribution UX is agent-first, recommends one path per harness, and keeps a portable fallback.
require_text "$ROOT/README.md" 'エージェントに依頼' "README does not lead with agent-assisted setup"
require_text "$ROOT/README.md" '手動で導入する' "README does not retain manual setup instructions"
require_text "$ROOT/README.md" 'codex plugin add hikizan@hikizan' "README is missing Codex fallback"
require_text "$ROOT/README.md" 'pi install git:github.com/hayashiii-ghub/hikizan' "README is missing pi installation"
require_text "$ROOT/README.md" '/plugin install hikizan@hikizan' "README is missing Claude fallback"
require_text "$ROOT/README.md" 'npx skills add github:hayashiii-ghub/hikizan -g' "README is missing universal fallback"
require_text "$ROOT/hooks/adapters/pi/README.md" 'https://github.com/hayashiii-ghub/shimon' "pi guide does not identify shimon"


exit "$fail"
