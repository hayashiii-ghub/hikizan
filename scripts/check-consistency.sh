#!/usr/bin/env bash
# Cross-file invariants not covered by the generators.
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
  require_text "$ROOT/README.md" "\`$name\`" "README does not mention $name"
  require_text "$ROOT/.claude-plugin/plugin.json" "$name" "Claude manifest does not mention $name"
done

# Generated manifests share one version and retain the native entrypoints.
cc_ver="$(jq -r .version "$ROOT/.claude-plugin/plugin.json")"
cur_ver="$(jq -r .version "$ROOT/.cursor-plugin/plugin.json")"
cx_ver="$(jq -r .version "$ROOT/.codex-plugin/plugin.json")"
[ "$cc_ver" = "$cur_ver" ] && [ "$cc_ver" = "$cx_ver" ] && ok "plugin manifest versions match ($cc_ver)" || bad "plugin manifest versions drift"
jq -e '.hooks == "hooks/adapters/cursor/hooks.json" and (has("rules") | not)' "$ROOT/.cursor-plugin/plugin.json" >/dev/null || bad "Cursor manifest does not point at the slim adapter"
jq -e '.hooks == "./hooks/adapters/codex/hooks.json" and .skills == "./skills/"' "$ROOT/.codex-plugin/plugin.json" >/dev/null || bad "Codex manifest does not point at the slim adapter"

# All harnesses share the same three floor classifiers.
cc_floors="$(grep -o 'pre-[a-z-]*\.sh' "$ROOT/hooks/hooks.json" | sort -u)"
cx_floors="$(grep -o 'pre-[a-z-]*\.sh' "$ROOT/hooks/adapters/codex/hooks.json" | sort -u)"
expected_floors="$(printf '%s\n' pre-destructive.sh pre-pr-create.sh pre-push.sh)"
[ "$cc_floors" = "$expected_floors" ] && [ "$cx_floors" = "$expected_floors" ] && ok "Claude and Codex wire the shared safety floors" || bad "hook floor wiring differs"
require_text "$ROOT/hooks/adapters/codex/hooks.json" 'pre-destructive.sh deny' "Codex destructive floor is not deny"
require_text "$ROOT/hooks/adapters/cursor/hooks.json" './hooks/adapters/cursor/before-shell.sh' "Cursor adapter path is stale"
[ -x "$ROOT/hooks/adapters/cursor/before-shell.sh" ] || bad "Cursor adapter is not executable"
for file in "$ROOT/hooks/hooks.json" "$ROOT/hooks/adapters/codex/hooks.json" "$ROOT/hooks/adapters/cursor/hooks.json"; do
  jq empty "$file" >/dev/null 2>&1 || bad "invalid JSON: ${file#$ROOT/}"
done

# Removed subsystems must not return through a generated or copied surface.
legacy=0
for path in agents codex context cursor docs opencode skills/init hooks/scripts/session-context.sh hooks/scripts/post-command.sh hooks/scripts/lib/metrics.sh; do
  if [ -d "$ROOT/$path" ]; then
    [ -z "$(find "$ROOT/$path" -type f -print -quit)" ] || { printf '✘ removed surface returned: %s\n' "$path"; legacy=1; }
  else
    [ ! -e "$ROOT/$path" ] || { printf '✘ removed surface returned: %s\n' "$path"; legacy=1; }
  fi
done
[ "$legacy" -eq 0 ] && ok "legacy context, metrics, adapter, and duplicate-doc surfaces stay removed" || fail=1

# Skills are installed as one pack; cross-skill references use logical names.
require_text "$ROOT/README.md" 'pack 単位' "README is missing the pack-only boundary"
skill_alt="$(jq -r '.core | join("|")' "$ROOT/scripts/skills.json")"
if grep -R -nE "skills/($skill_alt)/|(\.\./)+($skill_alt)/|($skill_alt)/references/" "$ROOT/skills"; then
  bad "runtime skill content contains repository-relative cross-skill references"
else
  ok "runtime cross-skill references use logical names"
fi

# Distribution UX is agent-first but keeps a manual fallback.
require_text "$ROOT/README.md" 'エージェントに依頼' "README does not lead with agent-assisted setup"
require_text "$ROOT/README.md" '手動fallback' "README does not retain a manual fallback"
require_text "$ROOT/README.md" 'codex plugin add hikizan@hikizan' "README is missing Codex fallback"
require_text "$ROOT/README.md" '/plugin install hikizan@hikizan' "README is missing Claude fallback"
require_text "$ROOT/README.md" 'npx skills add github:hayashiii-ghub/hikizan -g' "README is missing universal fallback"
require_text "$ROOT/README.md" '| Claude Code plugin | skills + safety hooks |' "README support matrix omits Claude Code"
require_text "$ROOT/README.md" '| Codex plugin | skills + safety hooks |' "README support matrix omits Codex"
require_text "$ROOT/README.md" '| Cursor plugin | skills + safety hooks |' "README support matrix omits Cursor"
require_text "$ROOT/README.md" '| Agent Skills対応ハーネス | skillsのみ |' "README support matrix omits the skills-only boundary"
require_text "$ROOT/README.md" 'https://github.com/hayashiii-ghub/shimon' "README does not identify the standard visual harness"
require_text "$ROOT/README.md" 'npm install --save-dev @hayashiii/shimon' "README omits the project-local Shimon install"
require_text "$ROOT/README.md" 'npx playwright install chromium' "README omits the Shimon browser install"

# Executable Markdown keeps the reviewed safety invariants from PR #148.
require_text "$ROOT/skills/sadoku/SKILL.md" '実行仕様 Markdown' "sadoku does not review executable Markdown"
require_text "$ROOT/skills/sadoku/references/project-context.md" 'git ls-files --others --exclude-standard -z' "sadoku omits untracked files"
require_text "$ROOT/skills/teishutsu/SKILL.md" '--body-file' "teishutsu does not use a PR body file"
require_text "$ROOT/skills/teishutsu/SKILL.md" 'PR_REMOTE / PR_URL / PR_REPO / PR_BASE / PR_BASE_REF' "teishutsu omits the qualified PR base"
require_text "$ROOT/skills/teishutsu/SKILL.md" 'push / PR作成への1行承認を得る' "teishutsu omits scope approval"
forbid_text "$ROOT/skills/teishutsu/SKILL.md" 'git fetch --all' "teishutsu fetches every remote"
require_text "$ROOT/skills/jikkou/references/tdd.md" 'git diff --cached --binary' "TDD witness omits the index"
require_text "$ROOT/skills/jikkou/references/tdd.md" 'git ls-files --others --exclude-standard -z' "TDD witness omits untracked content"
require_text "$ROOT/skills/teishutsu/references/pr-template.md" 'scanner関連fileが変更対象なら実行せず' "secret scan may execute an unreviewed scanner"
require_text "$ROOT/scripts/visual-contract.md" '自動installや別toolへのfallbackはしない' "visual policy allows implicit install/fallback"
require_text "$ROOT/scripts/visual-contract.md" '.shimon/task.config.mjs' "visual policy omits the task-local shimon config"
require_text "$ROOT/scripts/visual-contract.md" './node_modules/.bin/shimon verify --config .shimon/task.config.mjs --json' "visual policy omits the local-only shimon command"
require_text "$ROOT/scripts/visual-contract.md" 'shimon verify --case <name> --config ".shimon/task.config.mjs" --json' "visual policy does not recognize Shimon reproduce output"
require_text "$ROOT/skills/shippitsu/SKILL.md" 'references/writing-style.md' "shippitsu omits the standard writing profile"
require_text "$ROOT/skills/shippitsu/SKILL.md" 'references/cognitive-rhythm.md' "shippitsu omits the long-form writing profile"

# The documented token scan still catches representative formats.
token_line="$(awk '/^# hikizan:token-pattern$/ { getline; print; exit }' "$ROOT/skills/teishutsu/references/pr-template.md")"
token_pattern="$(printf '%s' "$token_line" | sed "s/^grep -E '//; s/' <draft>$//")"
token_ok=1
for fake in sk-1234567890abcdef ghp_1234567890abcdef github_pat_1234567890abcdef xoxb-1234567890abcdef; do
  printf '%s\n' "$fake" | grep -Eq "$token_pattern" || token_ok=0
done
[ "$token_ok" -eq 1 ] && ok "documented token scan covers representative formats" || bad "documented token scan misses a representative format"

exit "$fail"
