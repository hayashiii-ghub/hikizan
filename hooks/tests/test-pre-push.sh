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

# force-equivalent pushes (no --force flag) targeting a protected branch -> deny
hz_run_hook "$HOOK" "git push origin +HEAD:main" "$REPO_FEAT"
assert_eq "+refspec to main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push origin :main" "$REPO_FEAT"
assert_eq "delete refspec :main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --delete origin main" "$REPO_FEAT"
assert_eq "--delete origin main -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

hz_run_hook "$HOOK" "git push --mirror origin" "$REPO_FEAT"
assert_eq "--mirror -> deny" "deny" "$(hz_decision_of "$HZ_OUT")"

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

rm -rf "$REPO_MAIN" "$REPO_FEAT"

# ── non-ff remote resolution ──────────────────────────────────────────────
# fixture: two bare remotes (origin / other) plus a work clone in sync with
# both, then origin alone is advanced by a third clone so only origin is
# ahead of work's main. Exercises the remote resolution order (explicit ->
# branch.<name>.remote -> origin) that the non-ff check uses.
hz_mkrepo_with_remotes() { # -> path of work repo; sets HZ_BARE_ORIGIN / HZ_BARE_OTHER
  local bare_o bare_x work clone
  bare_o="$(mktemp -d)"; git init -q --bare "$bare_o"
  bare_x="$(mktemp -d)"; git init -q --bare "$bare_x"
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

rm -rf "$WORK" "$HZ_BARE_ORIGIN" "$HZ_BARE_OTHER"

hz_test_summary
