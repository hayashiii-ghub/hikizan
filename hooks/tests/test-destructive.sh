#!/usr/bin/env bash
# Unit tests for lib/destructive.sh — the classifier the pre-destructive hook
# uses to decide whether a Bash command needs explicit confirmation (C2).

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/destructive.sh"

lbl() { hz_destructive_label "$1"; }
hit() { if [ -n "$(hz_destructive_label "$1")" ]; then echo yes; else echo no; fi; }

# Destructive -> labelled
assert_eq "rm -rf"              "yes" "$(hit 'rm -rf build')"
assert_eq "rm -fr (reordered)"  "yes" "$(hit 'rm -fr /tmp/x')"
assert_eq "rm -Rf (capital R)"  "yes" "$(hit 'rm -Rf node_modules')"
assert_eq "rm -r -f (separate)" "yes" "$(hit 'rm -r -f dir')"
assert_eq "git reset --hard"    "yes" "$(hit 'git reset --hard HEAD~1')"
assert_eq "git clean -f"        "yes" "$(hit 'git clean -fd')"
assert_eq "git checkout -- ."   "yes" "$(hit 'git checkout -- .')"
assert_eq "git checkout ."      "yes" "$(hit 'git checkout .')"
assert_eq "git checkout -f"     "yes" "$(hit 'git checkout -f')"
assert_eq "git checkout <tree> -- path" "yes" "$(hit 'git checkout HEAD -- src/a.ts')"

# Benign -> not labelled
assert_eq "rm without recurse"  "no"  "$(hit 'rm file.txt')"
assert_eq "rm --force (non-recursive)" "no" "$(hit 'rm --force notes.txt')"
assert_eq "rmdir not rm"        "no"  "$(hit 'rmdir emptydir')"
assert_eq "git status"          "no"  "$(hit 'git status')"
assert_eq "git reset soft"      "no"  "$(hit 'git reset --soft HEAD~1')"
assert_eq "git checkout branch" "no"  "$(hit 'git checkout main')"
assert_eq "ls -rf is not rm"    "no"  "$(hit 'ls -la')"

# Label is human-readable
assert_contains "rm label mentions delete" "delete" "$(lbl 'rm -rf x')"

hz_test_summary
