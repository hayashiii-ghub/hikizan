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
require_text "$ROOT/scripts/contract.md" '最大3件を推奨順に`A（あ）`、`B（い）`、`C（う）`で示し' "shared contract omits bilingual handoff choices"
require_text "$ROOT/scripts/contract.md" '簡潔で分かりやすく書く' "shared contract omits lightweight prose guidance"
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
cc_ver="$(jq -r .version "$ROOT/.claude-plugin/plugin.json")"
cur_ver="$(jq -r .version "$ROOT/.cursor-plugin/plugin.json")"
cx_ver="$(jq -r .version "$ROOT/.codex-plugin/plugin.json")"
[ "$cc_ver" = "$cur_ver" ] && [ "$cc_ver" = "$cx_ver" ] && ok "plugin manifest versions match ($cc_ver)" || bad "plugin manifest versions drift"
jq -e '.hooks == "hooks/adapters/cursor/hooks.json" and .rules == "hooks/adapters/cursor/rules/"' "$ROOT/.cursor-plugin/plugin.json" >/dev/null || bad "Cursor manifest does not publish the routing rule and slim adapter"
jq -e '.hooks == "./hooks/adapters/codex/hooks.json" and .skills == "./skills/"' "$ROOT/.codex-plugin/plugin.json" >/dev/null || bad "Codex manifest does not point at the slim adapter"

# All harnesses share one PR merge checkpoint.
cc_hooks="$(grep -o 'pre-[a-z-]*\.sh' "$ROOT/hooks/hooks.json" | sort -u)"
cx_hooks="$(grep -o 'pre-[a-z-]*\.sh' "$ROOT/hooks/adapters/codex/hooks.json" | sort -u)"
oc_hooks="$(grep -o 'pre-[a-z-]*\.sh' "$ROOT/hooks/adapters/opencode/hikizan.ts" | sort -u)"
[ "$cc_hooks" = "pre-merge.sh" ] && [ "$cx_hooks" = "pre-merge.sh" ] && [ "$oc_hooks" = "pre-merge.sh" ] && ok "Claude, Codex, and OpenCode wire only the PR merge checkpoint" || bad "hook wiring is not minimal"
require_text "$ROOT/hooks/adapters/codex/hooks.json" 'pre-merge.sh deny Codex' "Codex merge checkpoint is not deny"
require_text "$ROOT/hooks/adapters/opencode/hikizan.ts" '"deny", "OpenCode"' "OpenCode merge checkpoint is not deny"
require_text "$ROOT/hooks/adapters/cursor/hooks.json" './hooks/adapters/cursor/before-shell.sh' "Cursor adapter path is stale"
require_text "$ROOT/hooks/hooks.json" 'session-routing.sh' "Claude does not load shared skill routing"
require_text "$ROOT/hooks/adapters/codex/hooks.json" 'session-routing.sh codex' "Codex does not load shared skill routing"
require_text "$ROOT/hooks/adapters/opencode/hikizan.ts" 'experimental.chat.system.transform' "OpenCode does not load shared skill routing"
require_text "$ROOT/hooks/adapters/cursor/rules/hikizan.mdc" 'alwaysApply: true' "Cursor routing rule is not always applied"
require_text "$ROOT/hooks/adapters/cursor/hooks.json" 'sessionStart' "Cursor does not load repository status at session start"
[ -x "$ROOT/hooks/adapters/cursor/before-shell.sh" ] || bad "Cursor adapter is not executable"
[ -x "$ROOT/hooks/scripts/session-routing.sh" ] || bad "session routing adapter is not executable"
[ -x "$ROOT/hooks/scripts/pre-merge.sh" ] || bad "merge checkpoint is not executable"
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

# Distribution UX is agent-first but keeps a manual fallback.
require_text "$ROOT/README.md" 'エージェントに依頼' "README does not lead with agent-assisted setup"
require_text "$ROOT/README.md" '手動で導入する' "README does not retain manual setup instructions"
require_text "$ROOT/README.md" 'codex plugin add hikizan@hikizan' "README is missing Codex fallback"
require_text "$ROOT/README.md" '/plugin install hikizan@hikizan' "README is missing Claude fallback"
require_text "$ROOT/README.md" 'npx skills add github:hayashiii-ghub/hikizan -g' "README is missing universal fallback"
require_text "$ROOT/README.md" '| Claude Codeプラグイン | スキル + 起動情報 + マージ承認 |' "README support matrix omits Claude Code routing"
require_text "$ROOT/README.md" '| Codexプラグイン | スキル + 起動情報 + マージ承認 |' "README support matrix omits Codex routing"
require_text "$ROOT/README.md" '| Cursorプラグイン | スキル + 起動情報 + マージ承認 |' "README support matrix omits Cursor routing"
require_text "$ROOT/README.md" '| OpenCode + ローカルアダプター | スキル + 起動情報 + マージ承認 |' "README support matrix omits OpenCode routing"
require_text "$ROOT/README.md" '| Agent Skills対応ハーネス | スキルのみ |' "README support matrix omits the skills-only boundary"
require_text "$ROOT/skills/tansaku/references/fanout.md" '親エージェントが必要範囲を読む' "tansaku fan-out omits the inline fallback"
forbid_text "$ROOT/skills/tansaku/references/fanout.md" 'Claude Code なら' "tansaku fan-out still singles out Claude Code"
require_text "$ROOT/skills/sadoku/references/persona-catalog.md" '親エージェントが確認する' "sadoku reviewer selection omits the inline fallback"
require_text "$ROOT/README.md" 'https://github.com/hayashiii-ghub/shimon' "README does not identify the standard visual harness"
require_text "$ROOT/README.md" 'npm install --save-dev @hayashiii/shimon' "README omits the project-local Shimon install"
require_text "$ROOT/README.md" 'npx playwright install chromium' "README omits the Shimon browser install"
require_text "$ROOT/skills/houkoku/references/writing-style.md" '自然な日本語がある概念を英単語のまま文章へ混ぜない' "writing style omits the Japanese prose boundary"
require_text "$ROOT/skills/houkoku/SKILL.md" 'references/cognitive-rhythm.md' "houkoku omits the long-form writing profile"
require_text "$ROOT/AGENTS.md" '日本語散文は`skills/houkoku/references/writing-style.md`' "AGENTS does not route Japanese prose to its source"

# Executable Markdown keeps the reviewed safety invariants from PR #148.
require_text "$ROOT/skills/sadoku/SKILL.md" '実行するMarkdown' "sadoku does not review executable Markdown"
require_text "$ROOT/skills/sadoku/SKILL.md" '未追跡ファイル' "sadoku omits untracked files"
require_text "$ROOT/skills/sadoku/SKILL.md" '機能ブランチの上流ブランチを比較元にしない' "sadoku may use a feature upstream as the review base"
require_text "$ROOT/skills/teishutsu/SKILL.md" '--body-file' "teishutsu does not use a PR body file"
require_text "$ROOT/skills/teishutsu/SKILL.md" '機能ブランチの上流ブランチを比較元にしない' "teishutsu may use a feature upstream as the PR base"
require_text "$ROOT/skills/teishutsu/SKILL.md" 'プッシュ先リモートとPR先リモートを分け' "teishutsu does not separate fork push and PR remotes"
require_text "$ROOT/skills/teishutsu/SKILL.md" '--draft`か`--reviewer`' "teishutsu may create an unreviewed ready PR"
forbid_text "$ROOT/skills/teishutsu/SKILL.md" 'git fetch --all' "teishutsu fetches every remote"
require_text "$ROOT/skills/teishutsu/references/pr-template.md" '検査器関連のファイルが変更対象なら実行せず' "secret scan may execute an unreviewed scanner"
require_text "$ROOT/skills/teishutsu/references/pr-template.md" '提出範囲の追加行' "secret scan omits added source content"
require_text "$ROOT/scripts/visual-contract.md" '自動インストールや別ツールへの切替は行わない' "visual policy allows implicit install/fallback"
require_text "$ROOT/scripts/visual-contract.md" '.shimon/task.mjs' "visual policy omits the task-local shimon cases"
require_text "$ROOT/scripts/visual-contract.md" './node_modules/.bin/shimon verify --task .shimon/task.mjs --json' "visual policy omits the local-only shimon command"
require_text "$ROOT/scripts/visual-contract.md" 'visualReviewRequired: true' "visual policy may confuse automated checks with visual review"
require_text "$ROOT/skills/houkoku/SKILL.md" 'references/writing-style.md' "houkoku omits the standard writing profile"
forbid_text "$ROOT/README.md" 'ln -sfn' "OpenCode fallback force-replaces an existing plugin"

# The documented token scan still catches representative formats.
token_line="$(awk '/^# hikizan:token-pattern$/ { getline; print; exit }' "$ROOT/skills/teishutsu/references/pr-template.md")"
token_pattern="$(printf '%s' "$token_line" | sed "s/^grep -E '//; s/' <draft>$//")"
token_ok=1
for fake in sk-1234567890abcdef ghp_1234567890abcdef github_pat_1234567890abcdef xoxb-1234567890abcdef; do
  printf '%s\n' "$fake" | grep -Eq "$token_pattern" || token_ok=0
done
[ "$token_ok" -eq 1 ] && ok "documented token scan covers representative formats" || bad "documented token scan misses a representative format"

exit "$fail"
