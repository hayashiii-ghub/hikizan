#!/usr/bin/env bash
# Unit tests for lib/destructive.sh — the classifier the pre-destructive hook
# uses to decide whether a Bash command needs explicit confirmation (C2).

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/destructive.sh"

lbl() { hz_destructive_label "$1"; }
hit() { if [ -n "$(hz_destructive_label "$1")" ]; then echo yes; else echo no; fi; }
sub() { hz_git_subcommand "$1"; }

# ── hz_git_subcommand (anchor for all git-shaped checks) ─────────────────
assert_eq "sub: git push"                "push"     "$(sub 'git push origin main')"
assert_eq "sub: git -C dir push"         "push"     "$(sub 'git -C /tmp/x push --force origin main')"
assert_eq "sub: git -c k=v push"         "push"     "$(sub 'git -c user.name=x push')"
assert_eq "sub: git stash push"          "stash"    "$(sub 'git stash push -m wip')"
assert_eq "sub: git commit (msg has push)" "commit" "$(sub 'git commit -m "use --force push now"')"
assert_eq "sub: command git push"        "push"     "$(sub 'command git push')"
assert_eq "sub: env-prefixed git reset"  "reset"    "$(sub 'GIT_TRACE=1 git reset --hard')"
assert_eq "sub: echo git push is not git" ""        "$(sub 'echo git push')"

# Destructive -> labelled
assert_eq "rm -rf"              "yes" "$(hit 'rm -rf build')"
assert_eq "rm -fr (reordered)"  "yes" "$(hit 'rm -fr /tmp/x')"
assert_eq "rm -Rf (capital R)"  "yes" "$(hit 'rm -Rf node_modules')"
assert_eq "rm -r -f (separate)" "yes" "$(hit 'rm -r -f dir')"
assert_eq "rm -rv -f (cluster + extra letter)" "yes" "$(hit 'rm -rv -f dir')"
assert_eq "sudo rm -rf"         "yes" "$(hit 'sudo rm -rf /tmp/x')"
assert_eq "env-prefixed git reset --hard" "yes" "$(hit 'GIT_TRACE=1 git reset --hard')"
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
# Quoted strings must NOT trigger — classification anchors on head/subcommand
assert_eq "commit msg mentions reset --hard" "no" "$(hit 'git commit -m "see reset --hard docs"')"
assert_eq "echo rm -rf is not rm"            "no" "$(hit 'echo rm -rf /')"
assert_eq "docker rm -rf is not rm"          "no" "$(hit 'docker rm -rf ctr')"
# Scope is the documented 分類規約: checkout pathspec without -- stays out
assert_eq "git checkout .gitignore (pathspec)" "no" "$(hit 'git checkout .gitignore')"

# Label is human-readable
assert_contains "rm label mentions delete" "delete" "$(lbl 'rm -rf x')"

# quote-aware floors: quoting a flag or subcommand must not smuggle a
# literal quote character into the token and defeat these anchored checks.
assert_eq "quoted rm -rf flag"        "yes" "$(hit 'rm "-rf" /tmp/x')"
assert_eq "quoted git reset --hard"   "yes" "$(hit 'git reset "--hard"')"
assert_eq "quoted git clean -f"       "yes" "$(hit 'git clean "-f"')"
assert_eq "quoted git checkout --force" "yes" "$(hit 'git checkout "--force"')"
assert_eq "quoted head token (git)"   "yes" "$(hit '"git" reset --hard')"
assert_eq "quoted subcommand (reset)" "yes" "$(hit 'git "reset" --hard')"

# ── compound commands: flag scans must not cross into later segments ─────
# Real false-asks (2026-07-05): a benign `git checkout -b` followed by an
# unrelated grep/mv segment must not be classified as a discard checkout.
assert_eq "checkout -b then grep -rn . (compound)" "no" \
  "$(hit 'git checkout -q -b feat && grep -rn "x" . | wc -l')"
assert_eq "checkout -b then mv then grep . (compound)" "no" \
  "$(hit 'git checkout -q -b feat && git mv a b && grep x .')"
assert_eq "reset --soft then echo --hard (compound)" "no" \
  "$(hit 'git reset --soft HEAD~1 && echo --hard')"
assert_eq "rm -r then tar -cf (compound, no rm -rf)" "no" \
  "$(hit 'rm -r x && tar -cf y.tar z')"
# Known limitation (same class as conditions.md's cd-passthrough note): a
# later segment's own discard checkout is not classified — only the first
# segment is scanned, matching the head-anchor policy used everywhere else.
assert_eq "checkout -b then checkout -- . (compound, known limit)" "no" \
  "$(hit 'git checkout -q -b x && git checkout -- .')"

hz_test_summary
