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
assert_eq "nested command substitution rm -rf" "yes" \
  "$(hit 'echo "$(rm -rf /tmp/x)"')"
assert_eq "nested backtick reset --hard" "yes" \
  "$(hit 'echo `git reset --hard`')"
assert_eq "later top-level rm -rf" "yes" \
  "$(hit 'echo ok; rm -rf /tmp/x')"
assert_eq "later nested rm -rf" "yes" \
  "$(hit 'echo "$(echo ok; rm -rf /tmp/x)"')"
assert_eq "commented nested-looking rm is benign" "no" \
  "$(hit 'echo ok # $(rm -rf /tmp/x)')"
assert_eq "quoted heredoc nested-looking rm is benign" "no" \
  "$(hit $'cat <<\'EOF\'\n$(rm -rf /tmp/x)\nEOF')"
assert_eq "unquoted heredoc nested rm is destructive" "yes" \
  "$(hit $'cat <<EOF\n$(rm -rf /tmp/x)\nEOF')"
assert_eq "env rm -rf" "yes" "$(hit 'env FOO=x rm -rf /tmp/x')"
assert_eq "sudo option rm -rf" "yes" "$(hit 'sudo -n rm -rf /tmp/x')"
assert_eq "command separator reset" "yes" "$(hit 'command -- git reset --hard')"
assert_eq "exec reset" "yes" "$(hit 'exec git reset --hard')"
assert_eq "reserved bang rm" "yes" "$(hit '! rm -rf /tmp/x')"
assert_eq "reserved then rm" "yes" "$(hit 'then rm -rf /tmp/x')"
assert_eq "brace group reset" "yes" "$(hit '{ git reset --hard')"
assert_eq "command query is benign" "no" "$(hit 'command -v rm -rf /tmp/x')"
assert_eq "env split-string rm -rf" "yes" "$(hit 'env -S "rm -rf /tmp/x"')"
assert_eq "attached env split-string rm -rf" "yes" "$(hit 'env -S"rm -rf /tmp/x"')"
assert_eq "env utility-path rm -rf" "yes" "$(hit 'env -P /bin rm -rf /tmp/x')"
assert_eq "case arm rm -rf" "yes" "$(hit 'case x in x) rm -rf /tmp/x ;; esac')"
assert_eq "single-quoted nested-looking text is benign" "no" \
  "$(hit "echo '\$(rm -rf /tmp/x)'")"

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
assert_eq "adjacent reset --hard before &&" "yes" \
  "$(hit 'git reset --hard&&echo ok')"
assert_eq "later --hard after adjacent && does not leak" "no" \
  "$(hit 'git reset --soft HEAD~1&&echo --hard')"
assert_eq "later -f after semicolon does not leak into rm" "no" \
  "$(hit 'rm -r x;echo -f')"
assert_eq "later -f after pipe does not leak into rm" "no" \
  "$(hit 'rm -r x|echo -f')"
assert_eq "later -f after ampersand does not leak into rm" "no" \
  "$(hit 'rm -r x&echo -f')"
assert_eq "later destructive segment is classified independently" "yes" \
  "$(hit 'echo ok&&git reset --hard')"
assert_eq "quoted operator argument is not a boundary" "yes" \
  "$(hit 'rm -r "&&" -f x')"
assert_eq "escaped operator argument is not a boundary" "yes" \
  "$(hit 'rm -r \&\& -f x')"
assert_eq "multiline quoted argument cannot hide later -f" "yes" \
  "$(hit $'rm -r "foo\n\nbar" -f target')"
assert_eq "command substitution cannot hide later -f" "yes" \
  "$(hit 'rm -r $(printf nope&&printf x) -f target')"
assert_eq "backtick substitution cannot hide later -f" "yes" \
  "$(hit 'rm -r `printf nope&&printf x` -f target')"
assert_eq "redirection before git subcommand is ignored" "yes" \
  "$(hit 'git >/tmp/out reset --hard')"
assert_eq "parameter expansion cannot hide later -f" "yes" \
  "$(hit 'rm -r ${v:-a&&b} -f target')"
assert_eq "backtick redirection target cannot hide subcommand" "yes" \
  "$(hit 'git >`printf /tmp/out&&printf x` reset --hard')"
assert_eq "top-level subshell exposes first destructive command" "yes" \
  "$(hit '(git reset --hard)')"
assert_eq "escaped backtick cannot hide later -f" "yes" \
  "$(hit 'rm -r `printf "x\`y" && printf z` -f target')"
assert_eq "nested escaped backticks cannot hide later -f" "yes" \
  "$(hit 'rm -r `printf %s \`printf x\` && :` -f target')"
assert_eq "command substitution quotes cannot hide later -f" "yes" \
  "$(hit 'rm -r "$(printf "%s" "x && y")" -f target')"
assert_eq "quoted io-number-shaped argv remains subcommand" "no" \
  "$(hit 'git "2">out reset --hard')"
assert_eq "escaped io-number-shaped argv remains subcommand" "no" \
  "$(hit 'git \2>out reset --hard')"
assert_eq "ANSI-C quoted force flag is destructive" "yes" \
  "$(hit "rm -r \$'-f' target")"
assert_eq "ANSI-C escaped hard flag is destructive" "yes" \
  "$(hit "git reset \$'--ha\\x72d'")"
# Each segment is classified independently, so flags do not leak across the
# boundary and a later destructive command is still caught.
assert_eq "checkout -b then checkout -- ." "yes" \
  "$(hit 'git checkout -q -b x && git checkout -- .')"

hz_test_summary
