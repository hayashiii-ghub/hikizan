#!/usr/bin/env bash
# Pure classifier for irreversible Bash commands. Returns a human label for
# commands that should require explicit confirmation, empty otherwise. No I/O —
# unit-tested in hooks/tests/test-destructive.sh.
#
# Scope (the four families the skills' 停止条件 already promise to guard):
#   rm -rf · git reset --hard · git clean -f · git checkout (discard)
#
# Tokenizing loops disable pathname expansion (set -f) so the verdict never
# depends on cwd contents.

# hz_is_rm_rf "<command>" -> exit 0 if it is an `rm` with both recurse and force.
hz_is_rm_rf() {
  local c="$1" tok seen_rm=0 hasr=0 hasf=0 rc=1 _g
  case $- in *f*) _g=1 ;; *) _g=0 ;; esac; set -f
  for tok in $c; do [ "$tok" = "rm" ] && seen_rm=1; done
  if [ "$seen_rm" = "1" ]; then
    for tok in $c; do
      case "$tok" in
        --recursive)               hasr=1 ;;
        --force)                   hasf=1 ;;
        --*)                       : ;;             # other long opt — NOT a -rf cluster
        -*[rR]*[fF]*|-*[fF]*[rR]*) rc=0; break ;;   # one short cluster with both
        -r|-R)                     hasr=1 ;;
        -f)                        hasf=1 ;;
      esac
    done
    [ "$rc" = 1 ] && [ "$hasr" = 1 ] && [ "$hasf" = 1 ] && rc=0
  fi
  [ "$_g" = 0 ] && set +f
  return $rc
}

# hz_destructive_label "<command>" -> print a label, or nothing if benign.
hz_destructive_label() {
  local c="$1" tok rc=0 out="" _g
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
      case $- in *f*) _g=1 ;; *) _g=0 ;; esac; set -f
      for tok in $c; do
        case "$tok" in -*[fF]*) out='git clean -f (deletes untracked files)'; break ;; esac
      done
      [ "$_g" = 0 ] && set +f
      if [ -n "$out" ]; then printf '%s' "$out"; return 0; fi ;;
  esac
  case "$c" in
    *"git checkout"*" -- "*|*"git checkout -- "*|*"git checkout ."*|*"git checkout -f"*|*"git checkout --force"*)
      printf 'git checkout (discards working-tree changes)'
      return 0 ;;
  esac
  return 0
}
