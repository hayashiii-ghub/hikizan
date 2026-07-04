#!/usr/bin/env bash
# Consistency lint for hikizan skills.
#
# Covers the invariants that generation cannot: the skills/ directory set,
# skill-name transcription, manifest versions, hook wiring parity, and the
# shared report footer (worktree line). The 共通ルール
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
cc_ver="$(awk -F'"' '/"version":/{print $4; exit}' "$ROOT/.claude-plugin/plugin.json")"
cur_ver="$(awk -F'"' '/"version":/{print $4; exit}' "$ROOT/.cursor-plugin/plugin.json")"
cx_ver="$(awk -F'"' '/"version":/{print $4; exit}' "$ROOT/.codex-plugin/plugin.json")"
if [ "$cc_ver" != "$cur_ver" ] || [ "$cc_ver" != "$cx_ver" ]; then
  echo "✘ plugin manifest versions drift: claude=$cc_ver cursor=$cur_ver codex=$cx_ver"; fail=1
else
  echo "✔ cursor/codex/claude plugin manifest versions match ($cc_ver)"
fi

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

# 10. Every core SKILL.md must keep the shared worktree detection line at the
#     end of its report template (hand-kept footer, presence only — teishutsu
#     was once missing it and the contract lint could not see that).
WT_LINE='worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。'
wt_missing=0
for name in $CORE; do
  grep -qF "$WT_LINE" "$ROOT/skills/$name/SKILL.md" || { echo "✘ skills/$name/SKILL.md is missing the worktree line in its report template"; wt_missing=1; }
done
fail=$((fail || wt_missing))
[ "$wt_missing" -eq 0 ] && echo "✔ report templates carry the worktree line"

exit "$fail"
