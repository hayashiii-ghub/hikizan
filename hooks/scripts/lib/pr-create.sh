#!/usr/bin/env bash
# Pure classification for `gh pr create` used by pre-pr-create.sh (CC) and
# before-shell.sh (Cursor) — same pure logic feeds both, only the I/O glue
# differs. No I/O here — unit-tested in hooks/tests/test-pr-create.sh.
#
# Anchored on each command head so argument text such as `echo gh pr create`
# never counts (a compound command like `cd x && gh pr create` still matches
# its second segment), and a quoted mention of --draft/-d/--reviewer/-r inside
# --title/--body text never counts as a real flag. Tokenizing goes through
# hz_tokenize (lib/tokenize.sh), a quote-aware char scanner.
command -v hz_tokenize >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/tokenize.sh"

# Exit 0 iff one simple segment starts with `gh pr create`, after the same
# lightweight wrapper/assignment prefixes supported by other classifiers.
_hz_is_pr_create_segment() {
  local tok state=0
  while IFS= read -r tok; do
    case "$state:$tok" in
      0:sudo|0:command|0:*=*) continue ;;
      0:gh) state=1 ;;
      1:pr) state=2 ;;
      2:create) return 0 ;;
      *) return 1 ;;
    esac
  done <<EOF
$(hz_first_segment "$1")
EOF
  return 1
}

_hz_is_pr_create_top() {
  local segment i=0
  hz_collect_command_segments "$1"
  while [ "$i" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
    segment="${HZ_COMMAND_SEGMENTS[$i]}"
    _hz_is_pr_create_segment "$segment" && return 0
    i=$((i + 1))
  done
  return 1
}

hz_is_pr_create() {
  local nested i=0
  _hz_is_pr_create_top "$1" && return 0
  hz_collect_nested_commands "$1"
  while [ "$i" -lt "$HZ_NESTED_COUNT" ]; do
    nested="${HZ_NESTED_COMMANDS[$i]}"
    _hz_is_pr_create_top "$nested" && return 0
    i=$((i + 1))
  done
  return 1
}

# hz_prcreate_needs_review "<command>" -> exit 0 iff the command is a
# `gh pr create` AND names neither --draft/-d nor --reviewer/--reviewer=*/-r
# (i.e. it should be denied). Exit 1 otherwise (allow, or not pr-create).
_hz_prcreate_segment_needs_review() {
  local tok has_draft=0 has_reviewer=0 state=0 skip_value=0
  while IFS= read -r tok; do
    if [ "$state" -lt 3 ]; then
      case "$state:$tok" in
        0:sudo|0:command|0:*=*) continue ;;
        0:gh) state=1 ;;
        1:pr) state=2 ;;
        2:create) state=3 ;;
        *) return 1 ;;
      esac
      continue
    fi
    if [ "$skip_value" = 1 ]; then
      skip_value=0
      continue
    fi
    case "$tok" in
      --draft|-d)                  has_draft=1 ;;
      --reviewer|--reviewer=*|-r)  has_reviewer=1 ;;
      --title|--body|--body-file|--base|--head|--assignee|--label|--milestone|--project|--template|-t|-b|-F|-B|-H|-a|-l|-m|-p|-T)
        skip_value=1 ;;
    esac
  done <<EOF
$(hz_first_segment "$1")
EOF

  [ "$state" = 3 ] && [ "$has_draft" = 0 ] && [ "$has_reviewer" = 0 ]
}

_hz_prcreate_needs_review_top() {
  local segment i=0
  hz_collect_command_segments "$1"
  while [ "$i" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
    segment="${HZ_COMMAND_SEGMENTS[$i]}"
    _hz_prcreate_segment_needs_review "$segment" && return 0
    i=$((i + 1))
  done
  return 1
}

hz_prcreate_needs_review() {
  local nested i=0
  _hz_prcreate_needs_review_top "$1" && return 0
  hz_collect_nested_commands "$1"
  while [ "$i" -lt "$HZ_NESTED_COUNT" ]; do
    nested="${HZ_NESTED_COMMANDS[$i]}"
    _hz_prcreate_needs_review_top "$nested" && return 0
    i=$((i + 1))
  done
  return 1
}
