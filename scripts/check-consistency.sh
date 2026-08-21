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

# Public implementation roots stay small. Hidden manifests and repository
# metadata remain at the root because the host platforms discover them there.
roots="$(find "$ROOT" -mindepth 2 -type f | sed "s#^$ROOT/##" | awk -F/ '$1 !~ /^\./ {print $1}' | sort -u | tr '\n' ' ' | sed 's/ $//')"
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
require_text "$ROOT/scripts/contract.md" '最大3件を推奨順に`A（あ）`、`I（い）`、`U（う）`で示し' "shared contract omits bilingual handoff choices"
require_text "$ROOT/scripts/contract.md" '簡潔で分かりやすく書く' "shared contract omits lightweight prose guidance"
require_text "$ROOT/scripts/contract.md" '同じ原因を防ぐ最小の共通箇所' "shared contract omits common-cause repair guidance"
require_text "$ROOT/scripts/contract.md" '要求外の一般化はしない' "shared contract omits the overgeneralization boundary"
require_text "$ROOT/scripts/contract.md" 'PRのマージと既定ブランチへの直接のpushは、利用者が依頼の終点として明示した場合だけ行う' "shared contract omits the merge and direct-push authority boundary"
for name in $CORE; do
  [ "$(grep -c '^## 次の進め方$' "$ROOT/skills/$name/SKILL.md")" = "1" ] || bad "skills/$name does not define exactly one handoff section"
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
jq -e '.hooks == "hooks/adapters/cursor/hooks.json" and .rules == "hooks/adapters/cursor/rules/"' "$ROOT/.cursor-plugin/plugin.json" >/dev/null || bad "Cursor manifest does not publish the routing rule and slim adapter"
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
    "@hayashiii/shimon": "^0.3.1"
  } and
  .pi.skills == ["./skills"] and
  .pi.extensions == ["./hooks/adapters/pi/index.ts"]
' "$ROOT/package.json" >/dev/null || bad "pi package does not publish the skills and slim adapter"

# All adapters expose startup routing and repository status; pi also owns its TUI and optional search surface.
jq -e '.hooks | keys == ["SessionStart"]' "$ROOT/hooks/hooks.json" >/dev/null || bad "Claude hook surface is not startup-only"
jq -e '.hooks | keys == ["SessionStart"]' "$ROOT/hooks/adapters/codex/hooks.json" >/dev/null || bad "Codex hook surface is not startup-only"
jq -e '.hooks | keys == ["sessionStart"]' "$ROOT/hooks/adapters/cursor/hooks.json" >/dev/null || bad "Cursor hook surface is not startup-only"
require_text "$ROOT/hooks/hooks.json" 'session-routing.sh' "Claude does not load shared skill routing"
require_text "$ROOT/hooks/adapters/codex/hooks.json" 'session-routing.sh codex' "Codex does not load shared skill routing"
require_text "$ROOT/hooks/adapters/cursor/rules/hikizan.mdc" 'alwaysApply: true' "Cursor routing rule is not always applied"
require_text "$ROOT/hooks/adapters/cursor/hooks.json" 'sessionStart' "Cursor does not load repository status at session start"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'pi.on("session_start"' "pi does not load startup information"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'SESSION_ROUTING, "pi"' "pi does not load shared skill routing"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'ctx.ui.setHeader' "pi does not expose the hikizan TUI header"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'pi.registerTool(createShimonTool())' "pi does not expose shimon visual verification"
require_text "$ROOT/hooks/adapters/pi/index.ts" 'registerExaSearchIfConfigured(pi)' "pi does not expose optional Exa search"
require_text "$ROOT/hooks/adapters/pi/exa-search.ts" 'if (!apiKey) return false' "pi Exa search is not gated by EXA_API_KEY"
require_text "$ROOT/hooks/adapters/pi/exa-client.js" 'type: "fast"' "pi Exa client does not use low-latency search"
require_text "$ROOT/hooks/adapters/pi/exa-client.js" 'case 402:' "pi Exa client does not stop on exhausted credit"
for symbol in 🌲 🌿 🔭 🧭 🛠️ 👀 🚀 ✍️; do
  forbid_text "$ROOT/hooks/adapters/pi/index.ts" "$symbol" "pi TUI embeds an emoji: $symbol"
done
[ -x "$ROOT/hooks/scripts/session-routing.sh" ] || bad "session routing adapter is not executable"
for file in "$ROOT/hooks/hooks.json" "$ROOT/hooks/adapters/codex/hooks.json" "$ROOT/hooks/adapters/cursor/hooks.json"; do
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
require_text "$ROOT/README.md" 'パック単位' "README is missing the pack-only boundary"
skill_alt="$(jq -r '.core | join("|")' "$ROOT/scripts/skills.json")"
if grep -R -nE "skills/($skill_alt)/|(\.\./)+($skill_alt)/|($skill_alt)/references/" "$ROOT/skills"; then
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
require_text "$ROOT/README.md" '| Agent Plugins対応クライアント | スキル |' "README support matrix omits Agent Plugins"
require_text "$ROOT/README.md" '| Claude Codeプラグイン | スキル + 起動情報 |' "README support matrix omits Claude Code routing"
require_text "$ROOT/README.md" '| Codex + Hookアダプター | Agent Pluginsのスキル + 起動情報 |' "README support matrix omits Codex routing"
require_text "$ROOT/README.md" '| Cursor + Hookアダプター | Agent Pluginsのスキル + 起動情報 |' "README support matrix omits Cursor routing"
require_text "$ROOT/README.md" '| piパッケージ | スキル + 起動情報 + TUI + 画面検証 + 任意Web検索 |' "README support matrix omits pi"
require_text "$ROOT/README.md" '| Agent Skills対応ハーネス | スキルのみ |' "README support matrix omits the skills-only boundary"
require_text "$ROOT/README.md" '## v1で守ること' "README does not define the v1 compatibility boundary"
require_text "$ROOT/README.md" '提供する範囲' "README overstates repository checks as a runtime guarantee"
require_text "$ROOT/skills/tansaku/references/fanout.md" '親エージェントが必要範囲を読む' "tansaku fan-out omits the inline fallback"
forbid_text "$ROOT/skills/tansaku/references/fanout.md" 'Claude Code なら' "tansaku fan-out still singles out Claude Code"
require_text "$ROOT/skills/sadoku/references/persona-catalog.md" '親エージェントが確認する' "sadoku reviewer selection omits the inline fallback"
require_text "$ROOT/README.md" 'https://github.com/hayashiii-ghub/shimon' "README does not identify shimon as a supported visual method"
require_text "$ROOT/skills/jikkou/SKILL.md" 'references/visual-verification.md' "jikkou does not route UI changes to visual verification"
require_text "$ROOT/skills/sadoku/SKILL.md" 'references/visual-verification.md' "sadoku does not route UI reviews to visual verification"
require_text "$ROOT/skills/houkoku/references/writing-style.md" '自然な日本語がある概念を英単語のまま文章へ混ぜない' "writing style omits the Japanese prose boundary"
require_text "$ROOT/skills/houkoku/SKILL.md" 'references/cognitive-rhythm.md' "houkoku omits the long-form writing profile"
require_text "$ROOT/AGENTS.md" '日本語散文は`skills/houkoku/references/writing-style.md`' "AGENTS does not route Japanese prose to its source"

# Executable Markdown keeps the reviewed safety invariants from PR #148.
require_text "$ROOT/skills/sadoku/SKILL.md" '実行するMarkdown' "sadoku does not review executable Markdown"
require_text "$ROOT/skills/sekkei/SKILL.md" 'その表現や一件だけを仕様にしない' "sekkei may turn one example into the whole specification"
require_text "$ROOT/skills/jikkou/SKILL.md" '同じ原因を通る代表的な入力' "jikkou omits representative common-cause verification"
require_text "$ROOT/skills/sadoku/SKILL.md" '提示されたケースだけを通す局所パッチ' "sadoku omits local-patch review"
require_text "$ROOT/skills/sadoku/SKILL.md" '未追跡ファイル' "sadoku omits untracked files"
require_text "$ROOT/skills/sadoku/SKILL.md" '機能ブランチの上流ブランチを比較元にしない' "sadoku may use a feature upstream as the review base"
require_text "$ROOT/skills/teishutsu/SKILL.md" '--body-file' "teishutsu does not use a PR body file"
require_text "$ROOT/skills/teishutsu/SKILL.md" '機能ブランチの上流ブランチを比較元にしない' "teishutsu may use a feature upstream as the PR base"
require_text "$ROOT/skills/teishutsu/SKILL.md" 'プッシュ先リモートとPR先リモートを分け' "teishutsu does not separate fork push and PR remotes"
require_text "$ROOT/skills/teishutsu/SKILL.md" '--draft`か`--reviewer`' "teishutsu may create an unreviewed ready PR"
forbid_text "$ROOT/skills/teishutsu/SKILL.md" 'git fetch --all' "teishutsu fetches every remote"
require_text "$ROOT/skills/teishutsu/references/pr-template.md" '検査器関連のファイルが変更対象なら実行せず' "secret scan may execute an unreviewed scanner"
require_text "$ROOT/skills/teishutsu/references/pr-template.md" '提出範囲の追加行' "secret scan omits added source content"
require_text "$ROOT/skills/houkoku/SKILL.md" 'references/writing-style.md' "houkoku omits the standard writing profile"
# The documented token scan still catches representative formats.
token_line="$(awk '/^# hikizan:token-pattern$/ { getline; print; exit }' "$ROOT/skills/teishutsu/references/pr-template.md")"
token_pattern="$(printf '%s' "$token_line" | sed "s/^grep -E '//; s/' <draft>$//")"
token_ok=1
for fake in sk-1234567890abcdef ghp_1234567890abcdef github_pat_1234567890abcdef xoxb-1234567890abcdef; do
  printf '%s\n' "$fake" | grep -Eq "$token_pattern" || token_ok=0
done
[ "$token_ok" -eq 1 ] && ok "documented token scan covers representative formats" || bad "documented token scan misses a representative format"

exit "$fail"
