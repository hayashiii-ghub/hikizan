#!/usr/bin/env bash
# Consistency lint for hikizan skills.
#
# Covers the invariants that generation cannot: the skills/ directory set,
# skill-name transcription, manifest versions, hook wiring parity, the
# hooks/conditions.md matrix, and the shared report footer (worktree line).
# The 共通ルール
# block itself is stamped by scripts/gen-contract.sh, whose --check (wired
# into check-all.sh) keeps the committed copies fresh.
#
# Exit 0 iff everything is consistent. Run: bash scripts/check-consistency.sh

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Core workflow skills carry the shared contract. Utility skills (e.g. init)
# are exempt — they have no contract block. The skill set and display order
# live in scripts/skills.json (single source, shared with gen-trigger-docs.sh).
CORE="$(jq -r '.core | join(" ")' "$ROOT/scripts/skills.json")"
UTILITY="$(jq -r '.utility | join(" ")' "$ROOT/scripts/skills.json")"
[ -n "$CORE" ] || { echo "✘ failed to read core skills from scripts/skills.json"; exit 1; }

fail=0

# 4. skills/ directory set must be exactly CORE ∪ {UTILITY}, both ways: a new
#    skill added without a CORE entry, or a renamed/removed skill whose old
#    name lingers in CORE, must fail loudly instead of silently passing.
dirs_missing=0
for name in $CORE $UTILITY; do
  [ -d "$ROOT/skills/$name" ] || { echo "✘ CORE/UTILITY lists $name but skills/$name does not exist"; dirs_missing=1; }
done
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  case " $CORE $UTILITY " in *" $name "*) ;; *) echo "✘ skills/$name exists but is not in CORE or UTILITY"; dirs_missing=1 ;; esac
done
fail=$((fail || dirs_missing))
[ "$dirs_missing" -eq 0 ] && echo "✔ skills/ directory set matches CORE ∪ {$UTILITY}"

# 7. skill name transcription: every CORE + UTILITY skill name must still be
#    mentioned in README.md, and every CORE name must appear in
#    context/routing.md (the routing table there is CORE-only by design —
#    UTILITY/init is manually invoked, not auto-routed, per README.md) and in
#    .claude-plugin/plugin.json's description. Presence only — a
#    removed/renamed skill's stale mention elsewhere is not checked here
#    because check 4 (directory set) already fails on rename.
transcription_missing=0
for name in $CORE $UTILITY; do
  grep -qF "$name" "$ROOT/README.md" || { echo "✘ README.md does not mention skill $name"; transcription_missing=1; }
done
for name in $CORE; do
  grep -qF "$name" "$ROOT/context/routing.md" || { echo "✘ context/routing.md does not mention skill $name"; transcription_missing=1; }
done
plugin_json="$ROOT/.claude-plugin/plugin.json"
plugin_desc="$(awk -F'"' '/"description":/{print $4; exit}' "$plugin_json")"
for name in $CORE; do
  case "$plugin_desc" in *"$name"*) ;; *) echo "✘ .claude-plugin/plugin.json description does not mention skill $name"; transcription_missing=1 ;; esac
done
fail=$((fail || transcription_missing))
[ "$transcription_missing" -eq 0 ] && echo "✔ skill names transcribed in README.md / context/routing.md / plugin.json description"

# 8. Cursor and Codex plugin manifest versions must track the CC plugin version.
#    Cursor also needs homepage / repository / license (same publish metadata as
#    Codex; gen-manifests.sh stamps them from plugin.src.json).
cc_ver="$(awk -F'"' '/"version":/{print $4; exit}' "$ROOT/.claude-plugin/plugin.json")"
cur_ver="$(awk -F'"' '/"version":/{print $4; exit}' "$ROOT/.cursor-plugin/plugin.json")"
cx_ver="$(awk -F'"' '/"version":/{print $4; exit}' "$ROOT/.codex-plugin/plugin.json")"
if [ "$cc_ver" != "$cur_ver" ] || [ "$cc_ver" != "$cx_ver" ]; then
  echo "✘ plugin manifest versions drift: claude=$cc_ver cursor=$cur_ver codex=$cx_ver"; fail=1
else
  echo "✔ cursor/codex/claude plugin manifest versions match ($cc_ver)"
fi
cursor_meta=0
jq -e '
  (.homepage | type == "string" and length > 0) and
  (.repository | type == "string" and length > 0) and
  (.license | type == "string" and length > 0) and
  (.description | type == "string" and contains("skills"))
' "$ROOT/.cursor-plugin/plugin.json" >/dev/null 2>&1 || { echo "✘ Cursor plugin manifest publish metadata is incomplete"; cursor_meta=1; }
fail=$((fail || cursor_meta))
[ "$cursor_meta" -eq 0 ] && echo "✔ Cursor plugin manifest publish metadata is present"

# 9. Hook wiring parity: the CC and Codex hook configs must wire the same set
#    of pre-* floor scripts, and each harness config must wire its own session
#    context / adapter entry point. Cursor and OpenCode wire adapters whose
#    floor sets are covered by hooks/tests instead.
cc_floors="$(grep -o 'pre-[a-z-]*\.sh' "$ROOT/hooks/hooks.json" | sort -u)"
cx_floors="$(grep -o 'pre-[a-z-]*\.sh' "$ROOT/codex/hooks.json" | sort -u)"
wiring=0
[ -n "$cc_floors" ] || { echo "✘ hooks/hooks.json wires no pre-* floor scripts"; wiring=1; }
if [ "$cc_floors" != "$cx_floors" ]; then
  echo "✘ floor script sets differ between hooks/hooks.json and codex/hooks.json"
  diff <(printf '%s\n' "$cc_floors") <(printf '%s\n' "$cx_floors") | sed 's/^/    /'
  wiring=1
fi
grep -q 'session-context\.sh' "$ROOT/hooks/hooks.json" || { echo "✘ hooks/hooks.json does not wire session-context.sh"; wiring=1; }
grep -q 'codex/scripts/session-context\.sh' "$ROOT/codex/hooks.json" || { echo "✘ codex/hooks.json does not wire codex/scripts/session-context.sh"; wiring=1; }
grep -q 'before-shell\.sh' "$ROOT/cursor/hooks.json" || { echo "✘ cursor/hooks.json does not wire before-shell.sh"; wiring=1; }
for script in pre-push.sh pre-pr-create.sh pre-destructive.sh; do
  grep -qF "$script" "$ROOT/opencode/hikizan.ts" || { echo "✘ opencode/hikizan.ts does not reuse $script"; wiring=1; }
done
fail=$((fail || wiring))
[ "$wiring" -eq 0 ] && echo "✔ hook wiring parity (CC/Codex floor set, Cursor/OpenCode adapters)"

# 10. hooks/conditions.md is the prose matrix AGENTS.md declares as SoT
#     alongside hooks/hooks.json. Presence only: every distinct `if` condition
#     wired in hooks/hooks.json must appear verbatim in conditions.md, so
#     rewiring hooks without updating the matrix fails loudly instead of
#     drifting silently. (test-hooks-json.sh guards the hooks.json side.)
cond="$ROOT/hooks/conditions.md"
cond_missing=0
while IFS= read -r prefix; do
  grep -qF "$prefix" "$cond" || { echo "✘ hooks/conditions.md does not mention wired condition $prefix"; cond_missing=1; }
done < <(grep -o '"if": *"[^"]*"' "$ROOT/hooks/hooks.json" | sed 's/^"if": *"//; s/"$//' | sort -u)
fail=$((fail || cond_missing))
[ "$cond_missing" -eq 0 ] && echo "✔ hooks/conditions.md mentions every wired if condition"

# 11. Every core SKILL.md must keep the shared worktree detection line at the
#     end of its report template (hand-kept footer, presence only — teishutsu
#     was once missing it and the contract lint could not see that).
WT_LINE='worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。'
wt_missing=0
for name in $CORE; do
  grep -qF "$WT_LINE" "$ROOT/skills/$name/SKILL.md" || { echo "✘ skills/$name/SKILL.md is missing the worktree line in its report template"; wt_missing=1; }
done
fail=$((fail || wt_missing))
[ "$wt_missing" -eq 0 ] && echo "✔ report templates carry the worktree line"

# 12. Commit guidance must not require an email-bearing attribution trailer.
# The shared contract forbids email in commit messages; contribution history
# belongs to the PR / hosting platform instead.
commit_footer=0
if grep -R -qF 'Co-Authored-By:' \
  "$ROOT/skills/jikkou/references" "$ROOT/skills/teishutsu/references"; then
  echo "✘ commit guidance requires a Co-Authored-By email trailer"; commit_footer=1
fi
fail=$((fail || commit_footer))
[ "$commit_footer" -eq 0 ] && echo "✔ commit guidance does not require email attribution trailers"

# 13. Codex distribution must stay on the current plugin contract. The CLI
#     command, marketplace metadata, published-manifest metadata, and the
#     Codex-specific destructive deny mode are one installable surface.
codex_dist=0
grep -qF 'codex plugin add hikizan@hikizan' "$ROOT/README.md" || { echo "✘ README.md is missing the current Codex plugin add command"; codex_dist=1; }
grep -qF 'codex plugin add hikizan@hikizan' "$ROOT/codex/README.md" || { echo "✘ codex/README.md is missing the current Codex plugin add command"; codex_dist=1; }
if grep -qF 'codex plugin install' "$ROOT/README.md" "$ROOT/codex/README.md"; then
  echo "✘ obsolete 'codex plugin install' command remains in Codex docs"; codex_dist=1
fi
jq -e '
  (.interface.displayName | type == "string" and length > 0) and
  (.plugins | length > 0) and
  all(.plugins[];
    (.policy.installation | type == "string" and length > 0) and
    (.policy.authentication | type == "string" and length > 0) and
    (.category | type == "string" and length > 0))
' "$ROOT/.agents/plugins/marketplace.json" >/dev/null 2>&1 || { echo "✘ Codex marketplace metadata is incomplete"; codex_dist=1; }
jq -e '
  (.homepage | type == "string" and length > 0) and
  (.repository | type == "string" and length > 0) and
  (.license | type == "string" and length > 0) and
  (.interface.displayName | type == "string" and length > 0)
' "$ROOT/.codex-plugin/plugin.json" >/dev/null 2>&1 || { echo "✘ Codex plugin manifest publish metadata is incomplete"; codex_dist=1; }
grep -q 'pre-destructive\.sh deny' "$ROOT/codex/hooks.json" || { echo "✘ Codex destructive hook is not wired in deny mode"; codex_dist=1; }
fail=$((fail || codex_dist))
[ "$codex_dist" -eq 0 ] && echo "✔ Codex distribution command, metadata, and hook mode are current"

# 14. Skills are distributed as one pack. Runtime skill content must refer to
#     another skill by its logical name, not by a repository-relative path
#     that becomes invalid or misleading when an installer relocates the pack.
pack_boundary=0
awk '
  $0 == "<!-- hikizan:pack-only -->" {
    if ((getline line) > 0 && line ~ /pack 単位/ && line ~ /部分 install/ && line ~ /サポートしない/) found=1
  }
  END { exit found ? 0 : 1 }
' "$ROOT/README.md" || {
  echo "✘ README.md does not state the pack-only installation boundary"; pack_boundary=1;
}
skill_alt="$(jq -r '[.core[], .utility[]] | join("|")' "$ROOT/scripts/skills.json")"
if grep -R -nE \
  "skills/($skill_alt)/|(\.\./)+($skill_alt)/|($skill_alt)/references/" \
  "$ROOT/skills"; then
  echo "✘ runtime skill content contains repository-relative cross-skill references"
  pack_boundary=1
fi
fail=$((fail || pack_boundary))
[ "$pack_boundary" -eq 0 ] && echo "✔ pack-only install boundary and logical cross-skill references"

# 15. Version-pin examples must survive a release without a docs-only bump.
#     vX.Y.Z is shell-safe; angle-bracket placeholders would be parsed as
#     redirection if copied as-is.
version_pin=0
if grep -nE -- '(--ref[[:space:]]+|--ref=)v[0-9]+\.[0-9]+\.[0-9]+' \
  "$ROOT/README.md" "$ROOT/codex/README.md"; then
  echo "✘ release-specific Codex --ref example remains in install docs"
  version_pin=1
fi
for file in "$ROOT/README.md" "$ROOT/codex/README.md"; do
  grep -qF -- '--ref vX.Y.Z' "$file" || {
    echo "✘ ${file#$ROOT/} is missing the release-independent --ref vX.Y.Z example"
    version_pin=1
  }
done
fail=$((fail || version_pin))
[ "$version_pin" -eq 0 ] && echo "✔ Codex version-pin examples are release-independent"

# 16. The documented token scan is executable guidance, so pin representative
#     fake formats here. Extract the regex from the recipe to keep one SoT.
secret_scan=0
token_line="$(awk '/^# hikizan:token-pattern$/ { getline; print; exit }' \
  "$ROOT/skills/teishutsu/references/pr-template.md")"
token_pattern="$(printf '%s' "$token_line" | sed "s/^grep -E '//; s/' <draft>$//")"
if [ -z "$token_pattern" ] || [ "$token_pattern" = "$token_line" ]; then
  echo "✘ token scan pattern is missing from the PR recipe"
  secret_scan=1
else
  for fake in \
    'sk-1234567890abcdef' \
    'sk-proj-1234567890abcdef' \
    'ghp_1234567890abcdef' \
    'github_pat_1234567890abcdef' \
    'xoxb-1234567890abcdef'; do
    printf '%s\n' "$fake" | grep -Eq "$token_pattern" || {
      echo "✘ token scan pattern misses fake format: ${fake%%[0-9]*}..."
      secret_scan=1
    }
  done
  for fake in \
    'AKIA'"ABCDEFGHIJKLMNOP" \
    'eyJabcdefghij.'"eyJklmnopqrst.uvwxyzABCD" \
    'Authorization: Bearer '"abcdefghijklmnop" \
    '-----BEGIN '"PRIVATE KEY-----"; do
    printf '%s\n' "$fake" | grep -Eq "$token_pattern" || {
      echo "✘ token scan pattern misses fake format: ${fake%%[0-9]*}..."
      secret_scan=1
    }
  done
  if printf '%s\n' 'sk-short' | grep -Eq "$token_pattern"; then
    echo "✘ token scan pattern matches an implausibly short token"
    secret_scan=1
  fi
fi
fail=$((fail || secret_scan))
[ "$secret_scan" -eq 0 ] && echo "✔ documented token scan covers representative current formats"

# 17. Distribution maintenance docs must point at hand-edited sources, keep
#     the pack-only boundary, and avoid hard-coded skill counts.
distribution_docs=0
skill_change_line="$(grep -F '**skill を足す / 減らすときは連動編集を全部通す**' "$ROOT/AGENTS.md" || true)"
printf '%s' "$skill_change_line" | grep -qF '`plugin.src.json`' || {
  echo "✘ AGENTS.md skill-change workflow does not point at plugin.src.json"
  distribution_docs=1
}
if printf '%s' "$skill_change_line" | grep -qF '`.claude-plugin/plugin.json`'; then
  echo "✘ AGENTS.md skill-change workflow tells editors to change a generated manifest"
  distribution_docs=1
fi
if grep -qF 'per-skill distribution channels' "$ROOT/scripts/gen-agents.sh"; then
  echo "✘ gen-agents.sh still describes unsupported per-skill distribution"
  distribution_docs=1
fi
if grep -qE 'skills [0-9]+ 個' "$ROOT/codex/README.md"; then
  echo "✘ codex/README.md hard-codes a stale skill count"
  distribution_docs=1
fi
fail=$((fail || distribution_docs))
[ "$distribution_docs" -eq 0 ] && echo "✔ distribution maintenance docs follow source and pack boundaries"

# 18. OpenCode currently ships as a local TypeScript adapter plus the shared
# skill-pack channel. Keep that experimental boundary explicit until a
# separately versioned npm package is designed and published.
opencode_dist=0
[ -f "$ROOT/opencode/hikizan.ts" ] || { echo "✘ OpenCode adapter is missing"; opencode_dist=1; }
for file in "$ROOT/README.md" "$ROOT/opencode/README.md"; do
  grep -qF 'HIKIZAN_ROOT' "$file" || { echo "✘ ${file#$ROOT/} is missing HIKIZAN_ROOT setup"; opencode_dist=1; }
  grep -qF 'npx skills add github:hayashiii-ghub/hikizan -g' "$file" || {
    echo "✘ ${file#$ROOT/} is missing the OpenCode skill-pack install command"; opencode_dist=1;
  }
done
grep -qF 'experimental.chat.system.transform' "$ROOT/opencode/hikizan.ts" || {
  echo "✘ OpenCode adapter does not inject session context"; opencode_dist=1;
}
grep -qF 'npm packageは未公開' "$ROOT/opencode/README.md" || {
  echo "✘ opencode/README.md does not state the npm distribution boundary"; opencode_dist=1;
}
fail=$((fail || opencode_dist))
[ "$opencode_dist" -eq 0 ] && echo "✔ OpenCode local adapter and experimental distribution boundary"

# 19. Skill Markdown is executable guidance. Keep the reviewed safety and
#     routing invariants pinned so a prose-only edit cannot silently restore a
#     broken command path.
skill_guidance=0
require_text() { # <file> <literal> <message>
  local file="$1" literal="$2" message="$3"
  grep -qF -- "$literal" "$file" || { echo "✘ $message"; skill_guidance=1; }
}
forbid_text() { # <file> <literal> <message>
  local file="$1" literal="$2" message="$3"
  if grep -qF -- "$literal" "$file"; then echo "✘ $message"; skill_guidance=1; fi
}

require_text "$ROOT/skills/sadoku/SKILL.md" '実行仕様 Markdown' \
  'sadoku does not treat executable Markdown as a review target'
require_text "$ROOT/skills/sadoku/references/project-context.md" 'BRANCH_SNAPSHOT' \
  'sadoku does not define a composite branch review descriptor'
require_text "$ROOT/skills/sadoku/references/project-context.md" 'git ls-files --others --exclude-standard -z' \
  'sadoku branch review omits untracked files'
if grep -qE 'git diff --name-only([[:space:]]*\||[[:space:]]*$)' \
  "$ROOT/skills/sadoku/references/project-context.md"; then
  echo '✘ sadoku still uses an unqualified git diff'
  skill_guidance=1
fi

require_text "$ROOT/skills/teishutsu/SKILL.md" '--body-file' \
  'teishutsu does not pass PR bodies through a file'
require_text "$ROOT/skills/teishutsu/SKILL.md" 'push URL' \
  'teishutsu does not include the push destination in its target check'
require_text "$ROOT/skills/teishutsu/SKILL.md" 'PR_REPO / PR_BASE / PR_HEAD' \
  'teishutsu does not bind the approved push to a PR target'
require_text "$ROOT/skills/teishutsu/SKILL.md" 'feature branchのupstreamをPR baseに使わない' \
  'teishutsu may reuse the feature upstream as its PR base'
forbid_text "$ROOT/skills/teishutsu/SKILL.md" 'git fetch --all' \
  'teishutsu still fetches every remote'
forbid_text "$ROOT/skills/teishutsu/SKILL.md" '**push**：`git push`' \
  'teishutsu still documents an implicit push destination'

forbid_text "$ROOT/skills/jikkou/SKILL.md" '`git status` clean' \
  'jikkou still requires a globally clean tree for PRUNE'
forbid_text "$ROOT/skills/jikkou/references/tdd.md" '/tmp/hikizan-prune.impl' \
  'TDD guidance still uses a fixed temporary path'
forbid_text "$ROOT/skills/jikkou/references/diagnosis-techniques.md" 'env | sort > local.env' \
  'diagnosis guidance still writes the full environment before redaction'
forbid_text "$ROOT/skills/jikkou/references/diagnosis-techniques.md" '/tmp/snapshot.log' \
  'diagnosis guidance still uses a fixed temporary path'
require_text "$ROOT/skills/jikkou/references/tdd.md" 'git diff --cached --binary' \
  'TDD witness fingerprint omits the index'
require_text "$ROOT/skills/jikkou/references/tdd.md" 'git ls-files --others --exclude-standard -z' \
  'TDD witness fingerprint omits untracked file content'
forbid_text "$ROOT/skills/jikkou/references/diagnosis-techniques.md" 'openat,connect,read,write' \
  'diagnosis trace still captures read/write buffers by default'

require_text "$ROOT/skills/init/SKILL.md" 'symlink' \
  'init does not define its symlink boundary'
require_text "$ROOT/skills/sadoku/references/synthesis.md" 'owner skill' \
  'sadoku synthesis does not route findings by owner skill'
require_text "$ROOT/skills/shippitsu/SKILL.md" '外部 optional skill' \
  'shippitsu does not qualify its external PDF handoff'
require_text "$ROOT/skills/teishutsu/references/pr-template.md" 'scanner関連fileが変更対象なら実行せず' \
  'secret scan may execute an unreviewed repo-owned scanner'
require_text "$ROOT/context/routing.md" 'Markdown仕様をレビューする' \
  'injected routing does not expose executable Markdown review'
require_text "$ROOT/scripts/visual-contract.md" '自動installや別toolへのfallbackはしない' \
  'visual policy no longer forbids automatic tool installation or fallback'
require_text "$ROOT/scripts/visual-contract.md" 'screenshot.mask' \
  'visual policy no longer requires screenshot secret masking'
require_text "$ROOT/scripts/visual-contract.md" '未reviewの変更なら自動実行せず' \
  'visual policy no longer blocks unreviewed verification configuration'
require_text "$ROOT/scripts/visual-contract.md" 'case名が`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`' \
  'visual policy no longer validates the verification case name'
require_text "$ROOT/scripts/visual-contract.md" 'canonical shimon形式 (`shimon verify --case <name> --json`) と一致' \
  'visual policy no longer requires the canonical reproduce command'
require_text "$ROOT/skills/teishutsu/SKILL.md" 'remoteは空文字と先頭`-`を拒否' \
  'submission remote validation accepts option-shaped values'
require_text "$ROOT/skills/teishutsu/SKILL.md" 'interrupt後は提出を続行しない' \
  'submission signal handling may continue after interruption'
require_text "$ROOT/skills/teishutsu/SKILL.md" 'PR_REMOTE / PR_URL / PR_REPO / PR_BASE / PR_BASE_REF' \
  'submission tuple omits the remote-qualified PR base'
require_text "$ROOT/skills/teishutsu/SKILL.md" 'push / PR作成への1行承認を得る' \
  'state-triggered submission does not re-confirm the resolved scope'

fail=$((fail || skill_guidance))
[ "$skill_guidance" -eq 0 ] && echo "✔ executable skill guidance keeps reviewed safety and routing invariants"

exit "$fail"
