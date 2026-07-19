#!/usr/bin/env bash
# Pure classifier for irreversible Bash commands. Returns a human label for
# commands that should require explicit confirmation, empty otherwise. No I/O —
# unit-tested in hooks/tests/test-destructive.sh.
#
# Scope (the four families the skills' 停止条件 already promise to guard):
#   rm -rf · git reset --hard · git clean -f · git checkout (discard)
#
# Classification is ANCHORED: the rm check requires `rm` to be the command head
# (sudo/command/env prefixes skipped), and the git checks require the matching
# git SUBCOMMAND. A quoted string that merely mentions "--force push" or
# "reset --hard" (e.g. a commit message) never triggers. Tokenizing goes
# through hz_tokenize (lib/tokenize.sh), a quote-aware char scanner — plain
# word-splitting (`for tok in $cmd`) doesn't strip quote characters, so a
# quoted flag (`rm "-rf" /path`) would leave a literal `"` in the token and
# defeat the exact-match checks below. It also never pathname-expands, so the
# verdict never depends on cwd contents.
command -v hz_tokenize >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/tokenize.sh"

# hz_cmd_head "<command>" -> first meaningful token (skips sudo / command /
# leading VAR=value assignments).
hz_cmd_head() {
  local tok out=""
  while IFS= read -r tok; do
    out="$tok"; break
  done <<EOF
$(hz_command_argv "$1")
EOF
  printf '%s' "$out"
}

# hz_git_subcommand "<command>" -> the git subcommand (push / reset / ...) when
# the command head is `git`, else empty. Skips git's own pre-subcommand flags
# (`-C <dir>`, `-c k=v`, `--git-dir <d>`, ...).
hz_git_subcommand() {
  local tok seen_git=0 skip=0 out=""
  while IFS= read -r tok; do
    if [ "$seen_git" = 0 ]; then
      [ "$tok" = "git" ] || break        # head is not git -> no subcommand
      seen_git=1; continue
    fi
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case "$tok" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path) skip=1 ;;
      --*) : ;;
      -*)  : ;;
      *)   out="$tok"; break ;;
    esac
  done <<EOF
$(hz_command_argv "$1")
EOF
  printf '%s' "$out"
}

# hz_is_rm_rf "<command>" -> exit 0 if it is an `rm` with both recurse and
# force (one cluster like -rf, or split across tokens like -rv -f).
hz_is_rm_rf() {
  local c="$1" tok hasr=0 hasf=0 rc=1
  [ "$(hz_cmd_head "$c")" = "rm" ] || return 1
  while IFS= read -r tok; do
    case "$tok" in
      --recursive)               hasr=1 ;;
      --force)                   hasf=1 ;;
      --*)                       : ;;             # other long opt — not a cluster
      -*[rR]*[fF]*|-*[fF]*[rR]*) rc=0; break ;;   # one short cluster with both
      -*[rR]*)                   hasr=1 ;;        # short cluster with r only
      -*[fF]*)                   hasf=1 ;;        # short cluster with f only
    esac
  done <<EOF
$(hz_command_argv "$c")
EOF
  [ "$rc" = 1 ] && [ "$hasr" = 1 ] && [ "$hasf" = 1 ] && rc=0
  return $rc
}

# _hz_has_tok "<command>" "<token>" -> exit 0 if an exact token is present.
_hz_has_tok() {
  local tok rc=1
  while IFS= read -r tok; do [ "$tok" = "$2" ] && { rc=0; break; }; done <<EOF
$(hz_command_argv "$1")
EOF
  return $rc
}

# _hz_has_short_f "<command>" -> exit 0 on a short cluster containing f (-f, -fd).
_hz_has_short_f() {
  local tok rc=1
  while IFS= read -r tok; do
    case "$tok" in --*) : ;; -*[fF]*) rc=0; break ;; esac
  done <<EOF
$(hz_command_argv "$1")
EOF
  return $rc
}

# Classify one simple command segment.
_hz_destructive_label_segment() {
  local c="$1" sub
  if [ "$(hz_cmd_head "$c")" = "__hikizan_unresolved_env_split__" ]; then
    printf 'env -S (unresolved command expansion)'
    return 0
  fi
  if hz_is_rm_rf "$c"; then
    printf 'rm -rf (recursive force delete)'
    return 0
  fi
  sub="$(hz_git_subcommand "$c")"
  case "$sub" in
    reset)
      if _hz_has_tok "$c" "--hard"; then
        printf 'git reset --hard (discards commits and working-tree changes)'
      fi ;;
    clean)
      if _hz_has_short_f "$c" || _hz_has_tok "$c" "--force"; then
        printf 'git clean -f (deletes untracked files)'
      fi ;;
    checkout)
      # discard forms: `git checkout [-tree-ish] -- <path>`, `git checkout .`,
      # `git checkout -f/--force`. A plain pathspec / branch switch stays out.
      if _hz_has_tok "$c" "--" || _hz_has_tok "$c" "." \
         || _hz_has_short_f "$c" || _hz_has_tok "$c" "--force"; then
        printf 'git checkout (discards working-tree changes)'
      fi ;;
  esac

  return 0
}

# hz_destructive_label "<command>" -> print a label, or nothing if benign.
hz_destructive_label() {
  local c="$1" segment nested label i=0 j=0 nested_count

  hz_collect_command_segments "$c"
  while [ "$i" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
    segment="${HZ_COMMAND_SEGMENTS[$i]}"
    label="$(_hz_destructive_label_segment "$segment")"
    if [ -n "$label" ]; then
      printf '%s' "$label"
      return 0
    fi
    i=$((i + 1))
  done

  hz_collect_nested_commands "$c"
  nested_count="$HZ_NESTED_COUNT"
  i=0
  while [ "$i" -lt "$nested_count" ]; do
    nested="${HZ_NESTED_COMMANDS[$i]}"
    hz_collect_command_segments "$nested"
    j=0
    while [ "$j" -lt "$HZ_COMMAND_SEGMENT_COUNT" ]; do
      segment="${HZ_COMMAND_SEGMENTS[$j]}"
      label="$(_hz_destructive_label_segment "$segment")"
      if [ -n "$label" ]; then
        printf 'nested command: %s' "$label"
        return 0
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
  return 0
}
