#!/usr/bin/env bash
# Unit tests for hooks/scripts/lib/pr-create.sh — the pure gh-pr-create
# classification pre-pr-create.sh (CC) and before-shell.sh (Cursor) share.
# Anchored on the quote-aware tokenizer (hz_tokenize) so a quoted mention of
# --draft/-d/--reviewer/-r inside --title/--body text never counts as a flag.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/pr-create.sh"

is_pr_create() { if hz_is_pr_create "$1"; then echo yes; else echo no; fi; }
needs_review() { if hz_prcreate_needs_review "$1"; then echo yes; else echo no; fi; }

# ── hz_is_pr_create ────────────────────────────────────────────────────────
assert_eq "gh pr create --title x -> is pr create" "yes" "$(is_pr_create 'gh pr create --title x')"
assert_eq "gh pr list -> not pr create"             "no"  "$(is_pr_create 'gh pr list')"
assert_eq "quoted gh pr create in commit msg -> not pr create" "no" \
  "$(is_pr_create 'git commit -m "gh pr create"')"
assert_eq "bare gh pr create -> is pr create"       "yes" "$(is_pr_create 'gh pr create')"

# ── hz_prcreate_needs_review ───────────────────────────────────────────────
assert_eq "bare create -> needs review (deny)"      "yes" "$(needs_review 'gh pr create --title x')"
assert_eq "--draft -> allow"                        "no"  "$(needs_review 'gh pr create --title x --draft')"
assert_eq "-d -> allow"                             "no"  "$(needs_review 'gh pr create -d')"
assert_eq "--reviewer bob -> allow"                 "no"  "$(needs_review 'gh pr create --reviewer bob')"
assert_eq "--reviewer=bob -> allow"                 "no"  "$(needs_review 'gh pr create --reviewer=bob')"
assert_eq "-r bob -> allow"                          "no"  "$(needs_review 'gh pr create -r bob')"
assert_eq 'quoted --draft in title -> deny (still needs review)' "yes" \
  "$(needs_review 'gh pr create --title "add --draft flag"')"
assert_eq "non pr-create command -> allow (not applicable)" "no" "$(needs_review 'gh pr list')"

hz_test_summary
