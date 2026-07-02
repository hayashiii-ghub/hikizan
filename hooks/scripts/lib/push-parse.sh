#!/usr/bin/env bash
# Pure git-push parsing for the pre-push hook. No I/O, no git calls — every
# function is a string transform so it can be unit-tested (hooks/tests/
# test-push-parse.sh) without a repo fixture.
#
# The force-protection check needs two facts from a raw command line:
#   1. is this a force-y push?            -> hikizan_push_has_force
#   2. which branch(es) would it write?   -> hikizan_push_targets
#
# Both tolerate the forms that bypassed the old awk: `HEAD:main` refspecs,
# an omitted ref (defaults to the current branch), and `git -C <dir>` /
# `command git` prefixes before the `push` verb.
#
# Every `for tok in $cmd` loop disables pathname expansion (set -f) so the
# verdict can never depend on what files happen to sit in the cwd.

# hz_push_dir "<command>" -> print the value of a `-C <dir>` argument that
# precedes the push verb, or nothing.
hz_push_dir() {
  local prev="" tok out="" _g; case $- in *f*) _g=1 ;; *) _g=0 ;; esac; set -f
  for tok in $1; do
    [ "$tok" = "push" ] && break
    if [ "$prev" = "-C" ]; then out="$tok"; break; fi
    prev="$tok"
  done
  [ "$_g" = 0 ] && set +f
  printf '%s' "$out"
}

# hikizan_push_has_force "<command>" -> exit 0 if a force flag is present.
hikizan_push_has_force() {
  local tok rc=1 _g; case $- in *f*) _g=1 ;; *) _g=0 ;; esac; set -f
  for tok in $1; do
    case "$tok" in
      --force|--force-with-lease|--force-with-lease=*) rc=0; break ;;
      --*) : ;;              # any other long flag is not a force flag
      -*f*|-*F*) rc=0; break ;; # short cluster containing f (e.g. -f, -fv, -vf)
    esac
  done
  [ "$_g" = 0 ] && set +f
  return $rc
}

# hikizan_push_is_forceful "<command>" -> exit 0 if the push is force-equivalent:
# an explicit force flag, or one of the other ways a push can force-update or
# delete a ref (--delete/-d, --mirror, --prune, a `+refspec` marker, or a
# `:dst` delete refspec).
hikizan_push_is_forceful() {
  hikizan_push_has_force "$1" && return 0

  local seen_push=0 skip_next=0 tok rc=1 _g
  case $- in *f*) _g=1 ;; *) _g=0 ;; esac; set -f
  for tok in $1; do
    if [ "$skip_next" = "1" ]; then skip_next=0; continue; fi
    if [ "$seen_push" = "0" ]; then
      [ "$tok" = "push" ] && seen_push=1
      continue
    fi
    case "$tok" in
      -o|--push-option|--receive-pack|--exec) skip_next=1 ;;  # value-taking
      --repo=*)                               : ;;
      --repo)                                 skip_next=1 ;;
      --delete|--mirror|--prune)               rc=0; break ;;
      --*)                                     : ;;           # other long flag
      -*d*)                                    rc=0; break ;; # short cluster containing d (-d, -vd)
      +*)                                      rc=0; break ;; # force-update refspec marker
      :*)                                      rc=0; break ;; # delete refspec (empty src)
      *)                                       : ;;
    esac
  done
  [ "$_g" = 0 ] && set +f
  return $rc
}

# _hz_norm_ref "<ref>" -> print the branch name with a refs/ prefix stripped.
_hz_norm_ref() {
  local r="$1"
  case "$r" in
    refs/heads/*)   r="${r#refs/heads/}" ;;
    refs/tags/*)    r="${r#refs/tags/}" ;;
    refs/remotes/*) r="${r#refs/remotes/}" ;;
  esac
  printf '%s\n' "$r"
}

# hikizan_push_targets "<command>" "<current_branch>" -> print each target
# branch name (one per line) the push would update.
hikizan_push_targets() {
  local cmd="$1" cur="$2"
  local seen_push=0 repo_flag=0 skip_next=0 tok _g
  local -a positionals=()

  case $- in *f*) _g=1 ;; *) _g=0 ;; esac; set -f
  for tok in $cmd; do
    if [ "$skip_next" = "1" ]; then skip_next=0; continue; fi
    if [ "$seen_push" = "0" ]; then
      [ "$tok" = "push" ] && seen_push=1
      continue
    fi
    case "$tok" in
      --repo=*)                                  repo_flag=1 ;;
      --repo)                                    repo_flag=1; skip_next=1 ;;
      -o|--push-option|--receive-pack|--exec)    skip_next=1 ;;  # value-taking
      --*) : ;;
      -*)  : ;;
      *)   positionals+=("$tok") ;;
    esac
  done
  [ "$_g" = 0 ] && set +f

  local -a refspecs=()
  if [ "$repo_flag" = "1" ]; then
    if [ "${#positionals[@]}" -ge 1 ]; then refspecs=("${positionals[@]}"); fi
  else
    if [ "${#positionals[@]}" -ge 2 ]; then refspecs=("${positionals[@]:1}"); fi
  fi

  if [ "${#refspecs[@]}" -eq 0 ]; then
    _hz_norm_ref "$cur"
    return 0
  fi

  local r
  for r in "${refspecs[@]}"; do
    r="${r#+}"                       # drop force-update marker
    case "$r" in *:*) r="${r##*:}" ;; esac  # take the destination (right of :)
    _hz_norm_ref "$r"
  done
}

# hikizan_push_protected_hit "<command>" "<current_branch>" -> print a
# human-readable description of the protected-branch hit and exit 0, or
# print nothing and exit 1. Single home for the protected-branch regex, in
# place of the duplicated while-loop that used to live in each hook.
hikizan_push_protected_hit() {
  local cmd="$1" cur="$2"
  local PROTECTED='^(main|master|develop)$'

  local seen_push=0 tok has_mirror=0 has_prune=0 _g
  case $- in *f*) _g=1 ;; *) _g=0 ;; esac; set -f
  for tok in $cmd; do
    if [ "$seen_push" = "0" ]; then
      [ "$tok" = "push" ] && seen_push=1
      continue
    fi
    case "$tok" in
      --mirror) has_mirror=1 ;;
      --prune)  has_prune=1 ;;
    esac
  done
  [ "$_g" = 0 ] && set +f

  if [ "$has_mirror" = "1" ]; then
    printf '%s' "--mirror (updates and prunes every ref, including protected branches)"; return 0
  fi
  if [ "$has_prune" = "1" ]; then
    printf '%s' "--prune (can delete protected branches absent locally)"; return 0
  fi

  local t
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    case "$t" in *[\*\?\[]*) printf '%s' "$t (wildcard refspec could match a protected branch)"; return 0 ;; esac
    if printf '%s' "$t" | grep -qE "$PROTECTED"; then printf '%s' "$t"; return 0; fi
  done <<EOF
$(hikizan_push_targets "$cmd" "$cur")
EOF
  return 1
}
