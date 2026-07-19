#!/usr/bin/env bash
# Integration tests for pre-push.sh. Each runs the real hook against a throwaway
# git repo and asserts the permission decision. The three force-protection
# bypasses (HEAD:main refspec, omitted ref, `git -C` prefix) are the C3 cases.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../scripts/pre-push.sh"

hz_mkrepo() { # <branch> -> path of a fresh repo on <branch>, no upstream
  local b="$1" d
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name tester
  git -C "$d" commit -q --allow-empty -m init
  git -C "$d" branch -M "$b"
  printf '%s' "$d"
}

REPO_MAIN="$(hz_mkrepo main)"
REPO_FEAT="$(hz_mkrepo feature)"
git -C "$REPO_FEAT" branch main

# C3 #1 — force push to main via HEAD:main refspec must be denied
hz_run_hook "$HOOK" "git push --force origin HEAD:main" "$REPO_MAIN"
assert_eq "force HEAD:main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

# C3 #2 — force push with omitted ref on branch main must be denied
hz_run_hook "$HOOK" "git push --force origin" "$REPO_MAIN"
assert_eq "force omitted-ref on main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

# C3 #3 — `git -C <dir> push --force ... HEAD:develop` must be denied
hz_run_hook "$HOOK" "git -C $REPO_MAIN push --force origin HEAD:develop" "/tmp"
assert_eq "git -C force HEAD:develop -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

# A-3: a wildcard refspec force push could expand to a protected branch -> deny
hz_run_hook "$HOOK" "git push --force origin refs/heads/*:refs/heads/*" "$REPO_MAIN"
assert_eq "wildcard refspec force -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

# force-with-lease to a protected branch is still a force push -> deny
hz_run_hook "$HOOK" "git push --force-with-lease origin main" "$REPO_MAIN"
assert_eq "force-with-lease main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --force-w origin main" "$REPO_MAIN"
assert_eq "abbreviated force-with-lease main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

# force push to a non-protected branch is allowed
hz_run_hook "$HOOK" "git push --force origin HEAD:feature" "$REPO_FEAT"
assert_eq "force to feature -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

# normal push (no force, no upstream divergence) is allowed
hz_run_hook "$HOOK" "git push origin main" "$REPO_MAIN"
assert_eq "plain push main -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

# a deny carries a human-readable reason
hz_run_hook "$HOOK" "git push --force origin main" "$REPO_MAIN"
assert_contains "deny reason names protected branch" "protected" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
assert_contains "force deny gives reachable manual recovery" "manually outside" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

hz_run_hook "$HOOK" 'echo "$(git push --force origin main)"' "$REPO_MAIN"
assert_eq "nested force push to main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git -C $REPO_FEAT -C . push --force origin" "/tmp"
assert_eq "unresolved multi-C force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"
assert_contains "unresolved context deny explains context" "resolve git repository context" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

hz_run_hook "$HOOK" 'echo ok; git push --force origin main' "$REPO_MAIN"
assert_eq "later top-level force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" 'echo "$(echo ok; git push --force origin main)"' "$REPO_MAIN"
assert_eq "later nested force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" $'echo "$(echo x # )\ngit push --force origin main\n)"' "$REPO_MAIN"
assert_eq "comment close-paren cannot hide nested force push" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" $'((1 << \'2\'\n + $(git push --force origin main; echo 0)))' "$REPO_MAIN"
assert_eq "arithmetic command cannot hide nested force push" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" $'a[1 << \'2\'\n + $(git push --force origin main; echo 0)]=x' "$REPO_MAIN"
assert_eq "array subscript cannot hide nested force push" "deny" "$(hz_decision_of "$HZ_OUT")"

# force-equivalent pushes (no --force flag) targeting a protected branch -> deny
hz_run_hook "$HOOK" "git push origin +HEAD:main" "$REPO_FEAT"
assert_eq "+refspec to main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push origin :main" "$REPO_FEAT"
assert_eq "delete refspec :main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --delete origin main" "$REPO_FEAT"
assert_eq "--delete origin main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --mirror origin" "$REPO_FEAT"
assert_eq "--mirror -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --del origin main" "$REPO_FEAT"
assert_eq "abbreviated --delete main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --mir origin" "$REPO_FEAT"
assert_eq "abbreviated --mirror -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --pru origin main" "$REPO_FEAT"
assert_eq "abbreviated --prune -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --force --al origin" "$REPO_FEAT"
assert_eq "abbreviated --all with force -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "env FOO=x git push --force origin main" "$REPO_MAIN"
assert_eq "env wrapped force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "exec git push --force origin main" "$REPO_MAIN"
assert_eq "exec wrapped force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "if git push --force origin main; then :; fi" "$REPO_MAIN"
assert_eq "if condition force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "if true; then git push --force origin main; fi" "$REPO_MAIN"
assert_eq "then body force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "env -S 'git push --force origin main'" "$REPO_MAIN"
assert_eq "env split-string force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "env -S'git\\_push\\_--force\\_origin\\_main'" "$REPO_MAIN"
assert_eq "attached env split-string force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "env -P /usr/bin git push --force origin main" "$REPO_MAIN"
assert_eq "env utility-path force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "case x in x) git push --force origin main ;; esac" "$REPO_MAIN"
assert_eq "case arm force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "env GIT_DIR=/other/.git git push --force origin" "$REPO_FEAT"
assert_eq "env changed git context force push -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --force --all origin" "$REPO_FEAT"
assert_eq "--force --all from feature -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --force origin main&&echo ok" "$REPO_FEAT"
assert_eq "adjacent compound suffix keeps protected target -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --force origin feature&&echo --all" "$REPO_FEAT"
assert_eq "later --all does not leak into first push -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --all origin" "$REPO_FEAT"
assert_eq "plain --all from feature -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --force -o --all origin feature" "$REPO_FEAT"
assert_eq "--all push-option value -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push -d origin develop" "$REPO_FEAT"
assert_eq "-d origin develop -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

# delete of a non-protected branch is not a floor violation
hz_run_hook "$HOOK" "git push --delete origin feature" "$REPO_FEAT"
assert_eq "--delete origin feature -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

# N-1: not actually a push — quoted message / other subcommand must pass through
hz_run_hook "$HOOK" 'git commit -m "use --force push now"' "$REPO_MAIN"
assert_eq "commit msg mentioning force push -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"
hz_run_hook "$HOOK" "git stash push -m wip" "$REPO_MAIN"
assert_eq "git stash push -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

# quote-aware floors: quoting the branch/flag must not smuggle a literal
# quote character past the exact-match protected-branch checks.
hz_run_hook "$HOOK" 'git push --force origin "main"' "$REPO_MAIN"
assert_eq "force quoted main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" 'git push origin --delete "main"' "$REPO_MAIN"
assert_eq "--delete quoted main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" 'git push origin :"main"' "$REPO_MAIN"
assert_eq "delete refspec quoted main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" 'git push "--mirror" origin' "$REPO_MAIN"
assert_eq "quoted --mirror -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

rm -rf "$REPO_MAIN" "$REPO_FEAT"

# ── non-ff remote resolution ──────────────────────────────────────────────
# fixture: two bare remotes (origin / other) plus a work clone in sync with
# both, then origin alone is advanced by a third clone so only origin is
# ahead of work's main. Exercises the remote resolution order (explicit ->
# branch.<name>.remote -> origin) that the non-ff check uses.
hz_mkrepo_with_remotes() { # -> path of work repo; sets HZ_BARE_ORIGIN / HZ_BARE_OTHER
  local bare_o bare_x work clone
  # -b main pins the bare repos' HEAD to refs/heads/main regardless of the
  # host's init.defaultBranch (e.g. still "master" on some CI runners) — a
  # mismatch there leaves HEAD dangling once "main" is pushed, and the later
  # `git clone` below fails to check anything out ("remote HEAD refers to
  # nonexistent ref"), silently breaking the "origin ahead" setup.
  bare_o="$(mktemp -d)"; git init -q --bare -b main "$bare_o"
  bare_x="$(mktemp -d)"; git init -q --bare -b main "$bare_x"
  work="$(mktemp -d)"
  git -C "$work" init -q
  git -C "$work" config user.email t@example.com
  git -C "$work" config user.name tester
  git -C "$work" commit -q --allow-empty -m init
  git -C "$work" branch -M main
  git -C "$work" remote add origin "$bare_o"
  git -C "$work" remote add other "$bare_x"
  git -C "$work" push -q origin main
  git -C "$work" push -q other main
  # advance origin only, from a separate clone, so origin is ahead of work
  clone="$(mktemp -d)"
  git clone -q "$bare_o" "$clone"
  git -C "$clone" config user.email t@example.com
  git -C "$clone" config user.name tester
  git -C "$clone" commit -q --allow-empty -m "origin ahead"
  git -C "$clone" push -q origin main
  rm -rf "$clone"
  HZ_BARE_ORIGIN="$bare_o"
  HZ_BARE_OTHER="$bare_x"
  printf '%s' "$work"
}

WORK="$(hz_mkrepo_with_remotes)"

# origin alone is ahead; pushing to the unrelated fork remote must not deny
hz_run_hook "$HOOK" "git push other main" "$WORK"
assert_eq "push to other (only origin ahead) -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

# explicit origin target keeps the old pinned behavior
hz_run_hook "$HOOK" "git push origin main" "$WORK"
assert_eq "push to origin (origin ahead) -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"
assert_contains "deny reason names the resolved remote" "origin" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"

# no explicit remote -> falls back to branch.<name>.remote config
git -C "$WORK" config branch.main.remote other
hz_run_hook "$HOOK" "git push" "$WORK"
assert_eq "config fallback to other (not ahead) -> allow" "allow" "$(hz_decision_of "$HZ_OUT")"

# Repository-controlled branch names in deny guidance must be shell-escaped.
git -C "$WORK" branch -m '$(id)'
git -C "$WORK" update-ref 'refs/remotes/origin/$(id)' refs/remotes/origin/main
git -C "$WORK" config 'branch.$(id).remote' origin
hz_run_hook "$HOOK" 'git push origin $(id)' "$WORK"
REASON="$(printf '%s' "$HZ_OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')"
assert_eq "hostile branch name still denies non-fast-forward push" "deny" "$(hz_decision_of "$HZ_OUT")"
assert_contains "deny guidance shell-escapes branch name" '\$\(id\)' "$REASON"
case "$REASON" in
  *'git pull --rebase origin $(id)'*)
    HZ_FAIL=$((HZ_FAIL + 1)); printf '  FAIL: deny guidance contains an unescaped executable branch name\n' ;;
  *) HZ_PASS=$((HZ_PASS + 1)) ;;
esac

rm -rf "$WORK" "$HZ_BARE_ORIGIN" "$HZ_BARE_OTHER"

hz_test_summary
