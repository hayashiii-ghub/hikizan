#!/usr/bin/env bash
# Unit tests for hooks/scripts/lib/push-parse.sh — the pure target/force
# resolution that the pre-push hook relies on. These tests pin the C3
# force-protection bypasses (refspec right-hand side, omitted ref, `git -C`,
# `command git`) so a regression re-opening the hole fails here first.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/push-parse.sh"

# ── hikizan_push_has_force ────────────────────────────────────────────────
force() { if hikizan_push_has_force "$1"; then echo yes; else echo no; fi; }

assert_eq "plain push is not force"              "no"  "$(force 'git push origin main')"
assert_eq "--force detected"                     "yes" "$(force 'git push --force origin HEAD:main')"
assert_eq "--force-with-lease detected"          "yes" "$(force 'git push --force-with-lease origin main')"
assert_eq "--force-with-lease=ref detected"      "yes" "$(force 'git push --force-with-lease=main origin main')"
assert_eq "-f detected"                          "yes" "$(force 'git push -f origin main')"
assert_eq "-f in short cluster (-fv) detected"   "yes" "$(force 'git push -fv origin main')"
assert_eq "trailing --force detected"            "yes" "$(force 'git push origin main --force')"
assert_eq "-v alone is not force"                "no"  "$(force 'git push -v origin main')"

# ── hikizan_push_targets ──────────────────────────────────────────────────
tgt() { hikizan_push_targets "$1" "$2" | paste -sd, - ; }

assert_eq "explicit ref"                         "main"          "$(tgt 'git push origin main' feat)"
# C3 bypass #1: refspec right-hand side must be the resolved target
assert_eq "refspec HEAD:main -> main"            "main"          "$(tgt 'git push --force origin HEAD:main' feat)"
# C3 bypass #2: omitted ref falls back to current branch
assert_eq "omitted ref -> current branch"        "main"          "$(tgt 'git push --force origin' main)"
assert_eq "remote only -> current branch"        "feat"          "$(tgt 'git push origin' feat)"
assert_eq "no args -> current branch"            "main"          "$(tgt 'git push' main)"
# C3 bypass #3: `git -C <dir>` prefix must still resolve the target
assert_eq "git -C prefix"                        "develop"       "$(tgt 'git -C /tmp/x push --force origin HEAD:develop' feat)"
assert_eq "command git prefix"                   "main"          "$(tgt 'command git push origin main' feat)"
assert_eq "src:dst refspec"                      "main"          "$(tgt 'git push origin feature:main' x)"
assert_eq "+force-update refspec"                "main"          "$(tgt 'git push origin +HEAD:main' x)"
assert_eq "delete refspec :main"                 "main"          "$(tgt 'git push origin :main' x)"
assert_eq "refs/heads/ stripped"                 "main"          "$(tgt 'git push origin refs/heads/main' x)"
assert_eq "multiple refspecs"                    "main,develop"  "$(tgt 'git push origin main develop' x)"
assert_eq "--repo value not treated as ref"      "main"          "$(tgt 'git push --repo origin main' x)"

# A-2: target resolution must be deterministic — never glob-expand against cwd.
GDIR="$(mktemp -d)"; : > "$GDIR/main"
assert_eq "no glob expansion (cwd has file 'main')" "ma*n" \
  "$(cd "$GDIR" && hikizan_push_targets 'git push origin ma*n' feat)"
rm -rf "$GDIR"

hz_test_summary
