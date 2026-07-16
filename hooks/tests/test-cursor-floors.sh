#!/usr/bin/env bash
# Tests for the Cursor floors adapter (cursor/scripts/before-shell.sh). Feeds
# Cursor-format input ({command, cwd}) and asserts the Cursor permission output.
# Exercises the same pure logic as the CC hooks, through the Cursor I/O glue.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../../cursor/scripts/before-shell.sh"

hz_mkrepo() { local b="$1" d; d="$(mktemp -d)"; git -C "$d" init -q
  git -C "$d" config user.email t@example.com; git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init; git -C "$d" branch -M "$b"; printf '%s' "$d"; }

run_cursor() { # <command> <cwd> -> sets HZ_OUT
  HZ_OUT=$(jq -nc --arg c "$1" --arg w "$2" '{command:$c, cwd:$w, conversation_id:"t"}' | bash "$HOOK" 2>/dev/null)
}
perm_of() { if [ -z "$1" ]; then echo allow; return; fi
  printf '%s' "$1" | jq -r '.permission // "allow"' 2>/dev/null || echo allow; }

REPO_MAIN="$(hz_mkrepo main)"
REPO_FEAT="$(hz_mkrepo feature)"
git -C "$REPO_FEAT" branch main

run_cursor "rm -rf build" "/tmp"
assert_eq "rm -rf -> ask" "ask" "$(perm_of "$HZ_OUT")"

run_cursor "git reset --hard HEAD~1" "/tmp"
assert_eq "reset --hard -> ask" "ask" "$(perm_of "$HZ_OUT")"

run_cursor "git reset --hard&&echo ok" "/tmp"
assert_eq "adjacent reset --hard -> ask" "ask" "$(perm_of "$HZ_OUT")"

run_cursor "git push --force origin HEAD:main" "$REPO_MAIN"
assert_eq "force HEAD:main -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor "git push \$'--fo\\x72ce' origin main" "$REPO_MAIN"
assert_eq "ANSI-C escaped force main -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor "git push --force origin" "$REPO_MAIN"
assert_eq "force omitted-ref on main -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor "git push --force origin HEAD:feature" "$REPO_FEAT"
assert_eq "force to feature -> allow" "allow" "$(perm_of "$HZ_OUT")"

run_cursor "git push origin +HEAD:main" "$REPO_MAIN"
assert_eq "+refspec to main -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor "git push --delete origin main" "$REPO_MAIN"
assert_eq "--delete origin main -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor "git push --force --all origin" "$REPO_FEAT"
assert_eq "--force --all from feature -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor "git push --force origin main&&echo ok" "$REPO_FEAT"
assert_eq "adjacent protected push -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor "git push --all origin" "$REPO_FEAT"
assert_eq "plain --all from feature -> allow" "allow" "$(perm_of "$HZ_OUT")"

run_cursor "git push origin :feature" "$REPO_FEAT"
assert_eq "delete refspec :feature -> allow" "allow" "$(perm_of "$HZ_OUT")"

run_cursor "ls -la" "/tmp"
assert_eq "benign -> allow" "allow" "$(perm_of "$HZ_OUT")"

run_cursor "rm -rf x" "/tmp"
assert_contains "ask carries message" "irreversible" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.agent_message // ""')"

# N-1: quoted strings / other subcommands must not trigger (no `if` filter here)
run_cursor 'git commit -m "use --force push now"' "$REPO_MAIN"
assert_eq "commit msg mentioning force push -> allow" "allow" "$(perm_of "$HZ_OUT")"
run_cursor 'git commit -m "see reset --hard docs"' "$REPO_MAIN"
assert_eq "commit msg mentioning reset --hard -> allow" "allow" "$(perm_of "$HZ_OUT")"
run_cursor "git stash push -m wip" "$REPO_MAIN"
assert_eq "git stash push -> allow" "allow" "$(perm_of "$HZ_OUT")"

# 3. non-draft PR without reviewer -> deny (parity with CC pre-pr-create)
run_cursor 'gh pr create --title x' "/tmp"
assert_eq "gh pr create bare -> deny" "deny" "$(perm_of "$HZ_OUT")"
assert_contains "PR deny gives reachable manual recovery" "manually outside" \
  "$(printf '%s' "$HZ_OUT" | jq -r '.agent_message // ""')"

run_cursor 'gh pr create --draft --title x' "/tmp"
assert_eq "gh pr create --draft -> allow" "allow" "$(perm_of "$HZ_OUT")"

run_cursor 'gh pr create --reviewer bob --title x' "/tmp"
assert_eq "gh pr create --reviewer bob -> allow" "allow" "$(perm_of "$HZ_OUT")"

run_cursor 'gh pr create --title "add --draft"' "/tmp"
assert_eq "gh pr create quoted --draft in title -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor 'gh pr create --title x&&echo --draft' "/tmp"
assert_eq "later segment --draft does not approve PR -> deny" "deny" "$(perm_of "$HZ_OUT")"

run_cursor 'gh pr create --title x # --draft' "/tmp"
assert_eq "commented --draft does not approve PR -> deny" "deny" "$(perm_of "$HZ_OUT")"

rm -rf "$REPO_MAIN" "$REPO_FEAT"
hz_test_summary
