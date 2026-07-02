#!/usr/bin/env bash
# hz_tokenize "<command>" -> print one token per line, honouring shell quoting.
# Pure bash (no external commands, bash 3.2 compatible), a plain char-by-char
# scan over `${str:i:1}` — no `eval`/`set --` involved so a hostile command
# string can never be re-interpreted.
#
# Rules:
#   - whitespace (space / tab / newline) splits tokens
#   - '...'  : literal, no escape processing inside
#   - "..."  : content taken as-is; \" and \\ unescape, any other \x stays \x
#   - backslash outside quotes: next char is taken literally (a\ b -> "a b")
#   - an unterminated quote flushes whatever was accumulated as the final
#     token and returns normally (deterministic, never an error)
#   - empty tokens (e.g. a bare '') are never printed
hz_tokenize() {
  local s="$1" i=0 len c nc cur=""
  len=${#s}
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"
    case "$c" in
      ' '|$'\t'|$'\n')
        [ -n "$cur" ] && printf '%s\n' "$cur"
        cur=""
        i=$((i + 1))
        ;;
      "'")
        i=$((i + 1))
        while [ "$i" -lt "$len" ]; do
          c="${s:$i:1}"
          i=$((i + 1))
          [ "$c" = "'" ] && break
          cur="$cur$c"
        done
        ;;
      '"')
        i=$((i + 1))
        while [ "$i" -lt "$len" ]; do
          c="${s:$i:1}"
          if [ "$c" = '"' ]; then
            i=$((i + 1))
            break
          elif [ "$c" = '\' ]; then
            nc="${s:$((i + 1)):1}"
            case "$nc" in
              '"'|'\')
                cur="$cur$nc"
                i=$((i + 2))
                ;;
              *)
                cur="$cur\\"
                i=$((i + 1))
                ;;
            esac
          else
            cur="$cur$c"
            i=$((i + 1))
          fi
        done
        ;;
      '\')
        nc="${s:$((i + 1)):1}"
        if [ -n "$nc" ]; then
          cur="$cur$nc"
          i=$((i + 2))
        else
          i=$((i + 1))
        fi
        ;;
      *)
        cur="$cur$c"
        i=$((i + 1))
        ;;
    esac
  done
  [ -n "$cur" ] && printf '%s\n' "$cur"
}
