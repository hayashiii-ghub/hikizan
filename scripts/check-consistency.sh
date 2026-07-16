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
#    context / adapter entry point. Cursor wires a single adapter
#    (before-shell.sh) whose floor set is covered by hooks/tests instead.
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
fail=$((fail || wiring))
[ "$wiring" -eq 0 ] && echo "✔ hook wiring parity (CC/Codex floor set, per-harness entry points)"

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

exit "$fail"
