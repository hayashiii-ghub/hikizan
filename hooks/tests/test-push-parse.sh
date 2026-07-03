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

# ── hikizan_push_is_forceful ──────────────────────────────────────────────
forceful() { if hikizan_push_is_forceful "$1"; then echo yes; else echo no; fi; }

assert_eq "plain push is not forceful"              "no"  "$(forceful 'git push origin main')"
assert_eq "+force-update refspec is forceful"       "yes" "$(forceful 'git push origin +HEAD:main')"
assert_eq "delete refspec :main is forceful"        "yes" "$(forceful 'git push origin :main')"
assert_eq "--delete is forceful"                    "yes" "$(forceful 'git push --delete origin main')"
assert_eq "-d is forceful"                          "yes" "$(forceful 'git push -d origin main')"
assert_eq "--mirror is forceful"                    "yes" "$(forceful 'git push --mirror origin')"
assert_eq "--prune is forceful"                      "yes" "$(forceful 'git push --prune origin main')"
assert_eq "--force is forceful (delegated)"         "yes" "$(forceful 'git push --force origin main')"
assert_eq "src:dst refspec is not forceful"         "no"  "$(forceful 'git push origin feature:main')"
assert_eq "value of value-taking flag is not forceful" "no" "$(forceful 'git push -o +weird origin main')"
assert_eq "trailing --delete is forceful"           "yes" "$(forceful 'git push origin main --delete')"

# quote-aware floors: a quoted branch name or flag must not smuggle a literal
# quote character into the token and defeat the exact-match checks below.
assert_eq "--force with quoted branch is forceful"  "yes" "$(forceful 'git push --force origin "main"')"
assert_eq "quoted --mirror is forceful"              "yes" "$(forceful 'git push "--mirror" origin')"

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

# quote-aware floors: quoting a refspec token must not leave literal quote
# characters in the resolved target name.
assert_eq "quoted branch name -> main"           "main"          "$(tgt 'git push --force origin "main"' feat)"
assert_eq "quoted refspec HEAD:\"main\" -> main" "main"          "$(tgt 'git push --force origin HEAD:"main"' feat)"
assert_eq "single-quoted branch name -> main"    "main"          "$(tgt "git push origin 'main'" feat)"

# A-2: target resolution must be deterministic — never glob-expand against cwd.
GDIR="$(mktemp -d)"; : > "$GDIR/main"
assert_eq "no glob expansion (cwd has file 'main')" "ma*n" \
  "$(cd "$GDIR" && hikizan_push_targets 'git push origin ma*n' feat)"
rm -rf "$GDIR"

# ── hikizan_push_remote ────────────────────────────────────────────────────
remote() { hikizan_push_remote "$1"; }

assert_eq "explicit remote"                      "origin"   "$(remote 'git push origin main')"
assert_eq "no args -> no remote"                 ""         "$(remote 'git push')"
assert_eq "flags before positional don't confuse" "origin"  "$(remote 'git push --force origin HEAD:main')"
assert_eq "--repo value wins"                    "upstream" "$(remote 'git push --repo upstream main')"
assert_eq "--repo=value wins"                    "upstream" "$(remote 'git push --repo=upstream')"
assert_eq "git -C prefix"                        "other"    "$(remote 'git -C /tmp/x push other feat')"
assert_eq "value-taking flag skip"               "other"    "$(remote 'git push -o opt other main')"

# ── hikizan_push_protected_hit ────────────────────────────────────────────
hit() { hikizan_push_protected_hit "$1" "$2" || true; }

assert_eq "force-update refspec hits main"       "main"    "$(hit 'git push origin +HEAD:main' x)"
assert_eq "delete refspec hits develop"          "develop" "$(hit 'git push origin :develop' x)"
assert_eq "delete of non-protected branch: no hit" ""      "$(hit 'git push --delete origin feature' x)"
assert_contains "--mirror hits regardless of target" "mirror" \
  "$(hit 'git push --mirror origin' feature)"
assert_contains "wildcard force refspec hit mentions wildcard" "wildcard" \
  "$(hit 'git push --force origin refs/heads/*:refs/heads/*' x)"
assert_eq "non-protected plain push: no hit"     ""        "$(hit 'git push origin feature' feature)"

# quote-aware floors: quoting the target/--delete/:dst must still hit main.
assert_contains "--delete quoted main hits"      "main"    "$(hit 'git push origin --delete "main"' x)"
assert_contains "quoted delete refspec :\"main\" hits" "main" "$(hit 'git push origin :"main"' x)"

hz_test_summary
