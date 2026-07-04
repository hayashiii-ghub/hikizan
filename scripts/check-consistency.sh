#!/usr/bin/env bash
# Consistency lint for hikizan skills.
#
#   1. The 共通ルール block (between the contract markers) must be byte-identical
#      across every skills/*/SKILL.md. It is inlined per skill (not a shared
#      file) so `npx skills add` per-skill copies keep it; this lint is what
#      keeps the copies from drifting.
#   2. Each SKILL.md must carry exactly one contract block.
#
# Exit 0 iff everything is consistent. Run: bash scripts/check-consistency.sh

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
START='<!-- hikizan:contract:start -->'
END='<!-- hikizan:contract:end -->'

extract() { awk -v s="$START" -v e="$END" '$0==s{f=1;next} $0==e{f=0} f' "$1"; }

# Core workflow skills carry the shared contract. Utility skills (e.g. init)
# are exempt — they have no contract block. The skill set and display order
# live in scripts/skills.json (single source, shared with gen-trigger-docs.sh).
CORE="$(jq -r '.core | join(" ")' "$ROOT/scripts/skills.json")"
UTILITY="$(jq -r '.utility | join(" ")' "$ROOT/scripts/skills.json")"
[ -n "$CORE" ] || { echo "✘ failed to read core skills from scripts/skills.json"; exit 1; }

fail=0
ref=""
ref_set=0
ref_file=""
count=0

for f in "$ROOT"/skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  name="$(basename "$(dirname "$f")")"
  case " $CORE " in *" $name "*) ;; *) continue ;; esac
  count=$((count + 1))

  # exactly one contract block
  starts=$(grep -cF "$START" "$f")
  ends=$(grep -cF "$END" "$f")
  if [ "$starts" != "1" ] || [ "$ends" != "1" ]; then
    echo "✘ $name: expected exactly one contract block (start=$starts end=$ends)"
    fail=1
    continue
  fi

  blk="$(extract "$f")"
  if [ "$ref_set" -eq 0 ]; then
    ref="$blk"; ref_file="$name"; ref_set=1
  elif [ "$blk" != "$ref" ]; then
    echo "✘ $name: 共通ルール block differs from $ref_file"
    diff <(printf '%s\n' "$ref") <(printf '%s\n' "$blk") | sed 's/^/    /' | head -20
    fail=1
  fi
done

if [ "$count" -eq 0 ]; then
  echo "✘ no skills found under $ROOT/skills"
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "✔ 共通ルール block identical across $count skills (ref: $ref_file)"
fi

# 3. plugin agents/ (first-class subagents) must match the per-skill fallback
#    copies under skills/sadoku/references/agents/ byte-for-byte.
for a in "$ROOT"/agents/*.md; do
  [ -e "$a" ] || continue
  base="$(basename "$a")"
  fb="$ROOT/skills/sadoku/references/agents/$base"
  if [ ! -f "$fb" ]; then
    echo "✘ agents/$base has no fallback at skills/sadoku/references/agents/$base"
    fail=1
  elif ! diff -q "$a" "$fb" >/dev/null; then
    echo "✘ agents/$base differs from its fallback copy"
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "✔ agents/ match references/agents/ fallback copies"

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

# 6. agents/ の逆方向: every fallback copy under skills/sadoku/references/agents/
#    must have a first-class counterpart under agents/ (pairs with check 3
#    above, which only checked agents/ -> fallback).
reverse_mismatch=0
for fb in "$ROOT"/skills/sadoku/references/agents/*.md; do
  [ -e "$fb" ] || continue
  base="$(basename "$fb")"
  if [ ! -f "$ROOT/agents/$base" ]; then
    echo "✘ skills/sadoku/references/agents/$base has no agents/$base"
    reverse_mismatch=1
  fi
done
fail=$((fail || reverse_mismatch))
[ "$reverse_mismatch" -eq 0 ] && echo "✔ references/agents/ fallback copies all have an agents/ counterpart"

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

exit "$fail"
