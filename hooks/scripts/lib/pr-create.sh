#!/usr/bin/env bash
# Pure classification for `gh pr create` used by pre-pr-create.sh (CC) and
# before-shell.sh (Cursor) — same pure logic feeds both, only the I/O glue
# differs. No I/O here — unit-tested in hooks/tests/test-pr-create.sh.
#
# Anchored on the token stream so `gh`->`pr`->`create` must be consecutive
# tokens (a compound command like `cd x && gh pr create` still matches once
# tokenized), and a quoted mention of --draft/-d/--reviewer/-r inside
# --title/--body text never counts as a real flag. Tokenizing goes through
# hz_tokenize (lib/tokenize.sh), a quote-aware char scanner.
command -v hz_tokenize >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/tokenize.sh"

# hz_is_pr_create "<command>" -> exit 0 iff the command contains `gh pr
# create` as three consecutive tokens.
hz_is_pr_create() {
  local tok prev="" prev2="" rc=1
  while IFS= read -r tok; do
    if [ -z "$tok" ]; then prev=""; prev2=""; continue; fi
    if [ "$prev2" = "gh" ] && [ "$prev" = "pr" ] && [ "$tok" = "create" ]; then
      rc=0
      break
    fi
    prev2="$prev"; prev="$tok"
  done <<EOF
$(hz_tokenize "$1")
EOF
  return $rc
}

# hz_prcreate_needs_review "<command>" -> exit 0 iff the command is a
# `gh pr create` AND names neither --draft/-d nor --reviewer/--reviewer=*/-r
# (i.e. it should be denied). Exit 1 otherwise (allow, or not pr-create).
hz_prcreate_needs_review() {
  local tok has_draft=0 has_reviewer=0 is_pr_create=0 prev="" prev2=""
  while IFS= read -r tok; do
    if [ -z "$tok" ]; then
      if [ "$is_pr_create" = 1 ] && [ "$has_draft" = 0 ] && [ "$has_reviewer" = 0 ]; then
        return 0
      fi
      has_draft=0; has_reviewer=0; is_pr_create=0; prev=""; prev2=""
      continue
    fi
    if [ "$is_pr_create" = 0 ]; then
      [ "$prev2" = "gh" ] && [ "$prev" = "pr" ] && [ "$tok" = "create" ] && is_pr_create=1
      prev2="$prev"; prev="$tok"
      continue
    fi
    case "$tok" in
      --draft|-d)                  has_draft=1 ;;
      --reviewer|--reviewer=*|-r)  has_reviewer=1 ;;
    esac
  done <<EOF
$(hz_tokenize "$1")
EOF

  [ "$is_pr_create" = 1 ] && [ "$has_draft" = 0 ] && [ "$has_reviewer" = 0 ]
}
