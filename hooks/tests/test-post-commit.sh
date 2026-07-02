#!/usr/bin/env bash
# Integration tests for post-commit.sh — the PostToolUse hook that warns when
# a parent commit moves a submodule pointer while the submodule itself still
# has unpushed commits. Includes the space-in-path regression case (C3-class:
# submodule.<name>.path can contain spaces; naive `awk '{print $2}'` /
# word-splitting silently drops everything after the first space).

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
HOOK="$DIR/../scripts/post-commit.sh"

hz_mkgit() { # <path> -- init a repo with user/email set, no remote
  git -C "$1" init -q
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name tester
}

# Build a standalone submodule-candidate repo (no remote configured, so
# `--not --remotes` treats every commit on it as unpushed).
hz_mk_submodule_source() {
  local d
  d="$(mktemp -d)"
  hz_mkgit "$d"
  git -C "$d" commit -q --allow-empty -m "submodule init"
  printf '%s' "$d"
}

# Build a parent repo with a submodule checked out at <path> (may contain
# spaces), pointer already committed on the parent.
hz_mk_parent_with_submodule() { # <path>
  local sm_path="$1" parent sub
  parent="$(mktemp -d)"
  sub="$(hz_mk_submodule_source)"
  hz_mkgit "$parent"
  git -C "$parent" commit -q --allow-empty -m "parent init"
  git -C "$parent" -c protocol.file.allow=always submodule add -q "$sub" "$sm_path" >/dev/null 2>&1
  # The submodule checkout is a fresh clone and does not inherit the source
  # repo's local identity — set it here or commits inside it fail on hosts
  # with no global identity (CI runners).
  git -C "$parent/$sm_path" config user.email t@example.com
  git -C "$parent/$sm_path" config user.name tester
  git -C "$parent" commit -q -m "add submodule $sm_path"
  printf '%s' "$parent"
}

# ── case 1: no .gitmodules at all -> no-op ──────────────────────────────
REPO1="$(mktemp -d)"
hz_mkgit "$REPO1"
: > "$REPO1/file.txt"
git -C "$REPO1" add file.txt
git -C "$REPO1" commit -q -m "plain commit"
hz_run_hook "$HOOK" "git commit -m plain" "$REPO1"
assert_exit "no .gitmodules: exit code" 0 "$HZ_CODE"
assert_eq "no .gitmodules: stderr empty" "" "$HZ_ERR"

# ── case 2: submodule pointer moved + unpushed commit on submodule ──────
REPO2="$(hz_mk_parent_with_submodule "sub")"
git -C "$REPO2/sub" commit -q --allow-empty -m "unpushed work"
git -C "$REPO2" add sub
git -C "$REPO2" commit -q -m "bump sub pointer"
hz_run_hook "$HOOK" "git commit -m bump" "$REPO2"
assert_exit "submodule unpushed: exit code" 0 "$HZ_CODE"
assert_contains "submodule unpushed: warns submodule name" "warning: submodule sub" "$HZ_ERR"
assert_contains "submodule unpushed: mentions unpushed" "unpushed" "$HZ_ERR"

# ── case 3: submodule path contains a space (the regression case) ──────
REPO3="$(hz_mk_parent_with_submodule "su b")"
git -C "$REPO3/su b" commit -q --allow-empty -m "unpushed work"
git -C "$REPO3" add "su b"
git -C "$REPO3" commit -q -m "bump su b pointer"
hz_run_hook "$HOOK" "git commit -m bump" "$REPO3"
assert_exit "space path: exit code" 0 "$HZ_CODE"
assert_contains "space path: warning names 'su b'" "su b" "$HZ_ERR"

# ── case 4: submodule exists but last commit doesn't touch the pointer ─
REPO4="$(hz_mk_parent_with_submodule "sub")"
git -C "$REPO4/sub" commit -q --allow-empty -m "unpushed work"
printf 'x' > "$REPO4/unrelated.txt"
git -C "$REPO4" add unrelated.txt
git -C "$REPO4" commit -q -m "unrelated change"
hz_run_hook "$HOOK" "git commit -m unrelated" "$REPO4"
assert_exit "pointer untouched: exit code" 0 "$HZ_CODE"
assert_eq "pointer untouched: stderr empty" "" "$HZ_ERR"

rm -rf "$REPO1" "$REPO2" "$REPO3" "$REPO4"
hz_test_summary
