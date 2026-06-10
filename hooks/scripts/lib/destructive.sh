#!/usr/bin/env bash
# Pure classifier for irreversible Bash commands. Returns a human label for
# commands that should require explicit confirmation, empty otherwise. No I/O —
# unit-tested in hooks/tests/test-destructive.sh.
#
# Scope (the four families the skills' 停止条件 already promise to guard):
#   rm -rf · git reset --hard · git clean -f · git checkout (discard)

# hz_is_rm_rf "<command>" -> exit 0 if it is an `rm` with both recurse and force.
hz_is_rm_rf() {
  local c="$1" tok seen_rm=0 hasr=0 hasf=0
  for tok in $c; do
    [ "$tok" = "rm" ] && seen_rm=1
  done
  [ "$seen_rm" = "0" ] && return 1
  for tok in $c; do
    case "$tok" in
      -*[rR]*[fF]*|-*[fF]*[rR]*) return 0 ;;   # one cluster carrying both
      -r|-R|--recursive)         hasr=1 ;;
      -f|--force)                hasf=1 ;;
    esac
  done
  [ "$hasr" = "1" ] && [ "$hasf" = "1" ] && return 0
  return 1
}

# hz_destructive_label "<command>" -> print a label, or nothing if benign.
hz_destructive_label() {
  local c="$1" tok
  if hz_is_rm_rf "$c"; then
    printf 'rm -rf (recursive force delete)'
    return 0
  fi
  case "$c" in
    *"reset --hard"*)
      printf 'git reset --hard (discards commits and working-tree changes)'
      return 0 ;;
  esac
  case "$c" in
    *"git clean"*)
      for tok in $c; do
        case "$tok" in
          -*[fF]*) printf 'git clean -f (deletes untracked files)'; return 0 ;;
        esac
      done ;;
  esac
  case "$c" in
    *"git checkout -- "*|*"git checkout ."*|*"git checkout -f"*|*"git checkout --force"*)
      printf 'git checkout (discards working-tree changes)'
      return 0 ;;
  esac
  return 0
}
