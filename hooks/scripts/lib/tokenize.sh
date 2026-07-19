#!/usr/bin/env bash
# hz_tokenize "<command>" -> print one token per line, honouring shell quoting.
# An empty line is a typed command-boundary record for an unquoted control
# operator (`&&`, `||`, `;`, `|`, `|&`, `&`) or an inter-command newline.
# Empty quoted arguments use the reserved non-empty record
# `__hikizan_empty_arg__`, so value-taking options keep their argv position
# while an empty line remains unambiguously a command boundary.
# Pure bash (no external commands, bash 3.2 compatible), a plain char-by-char
# scan over `${str:i:1}` — no `eval`/`set --` involved so a hostile command
# string can never be re-interpreted.
#
# Rules:
#   - space / tab splits tokens; an inter-command newline emits a boundary
#   - unquoted control operators emit one boundary (maximal-munch for pairs)
#   - top-level redirections and their target word are omitted (matching argv)
#   - control operators nested in `$()` / `()` / process substitution / backticks
#     stay inside their outer word; only top-level operators are boundaries
#   - physical newlines inside a word are normalized to the two characters `\n`
#   - '...'  : literal, no escape processing inside
#   - "..."  : content taken as-is; \" and \\ unescape, any other \x stays \x
#   - backslash outside quotes: next char is taken literally (a\ b -> "a b")
#   - an unterminated quote flushes whatever was accumulated as the final
#     token and returns normally (deterministic, never an error)
#   - empty argv (e.g. a bare '') prints the reserved empty-argument record
HZ_EMPTY_ARG='__hikizan_empty_arg__'

_hz_emit_word() { # <value> <word-started:0|1> <skip:0|1>
  local value="$1" started="$2" skip="$3"
  [ "$skip" = 0 ] || return 1
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  elif [ "$started" = 1 ]; then
    printf '%s\n' "$HZ_EMPTY_ARG"
  else
    return 1
  fi
}

hz_tokenize() {
  local s="$1" i=0 len c nc cur="" have_segment=0 nest=0 brace=0 top_group=0
  local word_start=1 want_redir=0 skip_word=0 target_started=0 opener="" io_candidate=1
  local word_started=0
  local heredoc_pending=0 heredoc_strip=0 heredoc_delim="" body_strip=0 h=0
  local -a heredoc_delims=() heredoc_strips=()
  local start line cmp qnest=0 qmode="" raw="" decoded="" ansi=""
  local j=0 ch="" esc="" ctl=0 oct=""
  len=${#s}
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"
    nc="${s:$((i + 1)):1}"

    # Redirections are shell syntax, not argv. Mark their next word for
    # omission, then let the normal scanner consume it so quote/substitution
    # handling has one implementation.
    if [ "$nest" = 0 ] && [ "$brace" = 0 ] && [ "$nc" != '(' ] \
      && { [ "$c" = '>' ] || [ "$c" = '<' ] \
      || { [ "$c" = '&' ] && [ "$nc" = '>' ]; }; }; then
      if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
        h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
        heredoc_pending=0; heredoc_strip=0
      fi
      if [ "$io_candidate" = 0 ]; then
        if _hz_emit_word "$cur" "$word_started" "$skip_word"; then have_segment=1; fi
      fi
      cur=""; skip_word=0; target_started=0; io_candidate=1; word_started=0

      opener="$c"
      if [ "$c" = '&' ]; then
        i=$((i + 2))
        [ "${s:$i:1}" = '>' ] && i=$((i + 1))
      else
        i=$((i + 1))
        if [ "$opener" = '>' ]; then
          case "${s:$i:1}" in '>'|'|'|'&') i=$((i + 1)) ;; esac
        else
          case "${s:$i:1}" in
            '<')
              i=$((i + 1))
              if [ "${s:$i:1}" = '<' ]; then
                i=$((i + 1))
              else
                heredoc_pending=1
                if [ "${s:$i:1}" = '-' ]; then heredoc_strip=1; i=$((i + 1)); else heredoc_strip=0; fi
              fi
              ;;
            '>'|'&') i=$((i + 1)) ;;
          esac
        fi
      fi
      want_redir=1; word_start=1
      continue
    fi

    if [ "$want_redir" = 1 ]; then
      case "$c" in
        ' '|$'\t') i=$((i + 1)); continue ;;
        $'\n'|';'|'|'|'&') want_redir=0; heredoc_pending=0 ;;
        '#') want_redir=0; heredoc_pending=0 ;;
        *) want_redir=0; skip_word=1; target_started=1 ;;
      esac
    fi

    case "$c" in
      ' '|$'\t')
        if [ "$nest" -gt 0 ] || [ "$brace" -gt 0 ]; then
          cur="$cur$c"; io_candidate=0
        else
          if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
            h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
            heredoc_pending=0; heredoc_strip=0
          fi
          if _hz_emit_word "$cur" "$word_started" "$skip_word"; then have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1; word_started=0
        fi
        word_start=1
        i=$((i + 1))
        ;;
      $'\n')
        if [ "$nest" -gt 0 ] || [ "$brace" -gt 0 ]; then
          cur="$cur\\n"; io_candidate=0
          word_start=1
          i=$((i + 1))
        else
          if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
            h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
            heredoc_pending=0; heredoc_strip=0
          fi
          if _hz_emit_word "$cur" "$word_started" "$skip_word"; then have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1; word_started=0
          if [ "$have_segment" = 1 ]; then printf '\n'; have_segment=0; fi
          word_start=1
          i=$((i + 1))
          if [ "${#heredoc_delims[@]}" -gt 0 ]; then
            h=0
            while [ "$h" -lt "${#heredoc_delims[@]}" ]; do
              heredoc_delim="${heredoc_delims[$h]}"; body_strip="${heredoc_strips[$h]}"
            while [ "$i" -lt "$len" ]; do
              start=$i
              while [ "$i" -lt "$len" ] && [ "${s:$i:1}" != $'\n' ]; do i=$((i + 1)); done
              line="${s:$start:$((i - start))}"; cmp="$line"
              if [ "$body_strip" = 1 ]; then
                while [ "${cmp:0:1}" = $'\t' ]; do cmp="${cmp:1}"; done
              fi
              if [ "$cmp" = "$heredoc_delim" ]; then
                [ "$i" -lt "$len" ] && i=$((i + 1))
                break
              fi
              [ "$i" -lt "$len" ] && i=$((i + 1))
            done
              h=$((h + 1))
            done
            heredoc_delims=(); heredoc_strips=(); heredoc_delim=""; body_strip=0
          fi
        fi
        ;;
      ';')
        if [ "$nest" -gt 0 ] || [ "$brace" -gt 0 ]; then
          cur="$cur$c"; io_candidate=0
        else
          if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
            h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
            heredoc_pending=0; heredoc_strip=0
          fi
          if _hz_emit_word "$cur" "$word_started" "$skip_word"; then have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1; word_started=0
          if [ "$have_segment" = 1 ]; then printf '\n'; have_segment=0; fi
        fi
        word_start=1
        i=$((i + 1))
        ;;
      '&')
        if [ "$nest" -gt 0 ] || [ "$brace" -gt 0 ]; then
          cur="$cur$c"; io_candidate=0
          i=$((i + 1))
        else
          if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
            h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
            heredoc_pending=0; heredoc_strip=0
          fi
          if _hz_emit_word "$cur" "$word_started" "$skip_word"; then have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1; word_started=0
          if [ "$have_segment" = 1 ]; then printf '\n'; have_segment=0; fi
          if [ "$nc" = '&' ]; then i=$((i + 2)); else i=$((i + 1)); fi
        fi
        word_start=1
        ;;
      '|')
        if [ "$nest" -gt 0 ] || [ "$brace" -gt 0 ]; then
          cur="$cur$c"; io_candidate=0
          i=$((i + 1))
        else
          if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
            h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
            heredoc_pending=0; heredoc_strip=0
          fi
          if _hz_emit_word "$cur" "$word_started" "$skip_word"; then have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1; word_started=0
          if [ "$have_segment" = 1 ]; then printf '\n'; have_segment=0; fi
          case "$nc" in '|'|'&') i=$((i + 2)) ;; *) i=$((i + 1)) ;; esac
        fi
        word_start=1
        ;;
      '(')
        if [ "$nest" = 0 ] && [ "$brace" = 0 ] && [ "$word_start" = 1 ] \
          && [ -z "$cur" ] && [ "$skip_word" = 0 ]; then
          top_group=$((top_group + 1))
        else
          cur="$cur$c"; nest=$((nest + 1)); word_start=1; io_candidate=0; word_started=1
        fi
        i=$((i + 1))
        ;;
      ')')
        if [ "$nest" -gt 0 ]; then
          cur="$cur$c"; nest=$((nest - 1)); word_start=0; io_candidate=0; word_started=1
        elif [ "$brace" = 0 ] && [ "$top_group" -gt 0 ]; then
          if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
            h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
            heredoc_pending=0; heredoc_strip=0
          fi
          if _hz_emit_word "$cur" "$word_started" "$skip_word"; then have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1; word_started=0
          if [ "$have_segment" = 1 ]; then printf '\n'; have_segment=0; fi
          top_group=$((top_group - 1)); word_start=1
        else
          cur="$cur$c"; word_start=0; io_candidate=0; word_started=1
        fi
        i=$((i + 1))
        ;;
      '$')
        if [ "$nc" = "'" ]; then
          raw=""; word_start=0; io_candidate=0; word_started=1; i=$((i + 2))
          while [ "$i" -lt "$len" ]; do
            c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
            if [ "$c" = '\' ] && [ -n "$nc" ]; then
              raw="$raw$c$nc"; i=$((i + 2)); continue
            fi
            if [ "$c" = "'" ]; then i=$((i + 1)); break; fi
            raw="$raw$c"; i=$((i + 1))
          done
          ansi=""; j=0
          while [ "$j" -lt "${#raw}" ]; do
            ch="${raw:$j:1}"; esc="${raw:$((j + 1)):1}"
            if [ "$ch" = '\' ] && [ -n "$esc" ]; then
              if [ "$esc" = 'c' ] && [ "$((j + 2))" -lt "${#raw}" ]; then
                ch="${raw:$((j + 2)):1}"
                if [ "$ch" = '?' ]; then ctl=127
                else printf -v ctl '%d' "'$ch"; ctl=$((ctl & 31)); fi
                printf -v oct '%03o' "$ctl"; ansi="$ansi\\$oct"; j=$((j + 3))
              else
                ansi="$ansi$ch$esc"; j=$((j + 2))
              fi
            else
              ansi="$ansi$ch"; j=$((j + 1))
            fi
          done
          printf -v decoded '%b' "$ansi"
          decoded="${decoded//$'\n'/\\n}"
          cur="$cur$decoded"
        elif [ "$nc" = '"' ]; then
          # Locale-translated quoting has double-quote shell structure. The
          # locale marker itself is not part of argv; scan the quote normally.
          i=$((i + 1))
        elif [ "$nc" = '{' ]; then
          cur="$cur\${"; brace=$((brace + 1)); word_start=0; io_candidate=0; word_started=1; i=$((i + 2))
        else
          cur="$cur$c"; word_start=0; io_candidate=0; word_started=1; i=$((i + 1))
        fi
        ;;
      '}')
        cur="$cur$c"
        [ "$brace" -gt 0 ] && brace=$((brace - 1))
        word_start=0; io_candidate=0; word_started=1
        i=$((i + 1))
        ;;
      '#')
        if [ "$brace" = 0 ] && [ "$word_start" = 1 ]; then
          while [ "$i" -lt "$len" ] && [ "${s:$i:1}" != $'\n' ]; do i=$((i + 1)); done
        else
          cur="$cur$c"
          word_start=0; io_candidate=0
          i=$((i + 1))
        fi
        ;;
      "'")
        word_start=0; io_candidate=0; word_started=1
        i=$((i + 1))
        while [ "$i" -lt "$len" ]; do
          c="${s:$i:1}"
          i=$((i + 1))
          [ "$c" = "'" ] && break
          if [ "$c" = $'\n' ]; then cur="$cur\\n"; else cur="$cur$c"; fi
        done
        ;;
      '"')
        word_start=0; io_candidate=0; word_started=1
        i=$((i + 1))
        while [ "$i" -lt "$len" ]; do
          c="${s:$i:1}"
          nc="${s:$((i + 1)):1}"
          if [ "$c" = '$' ] && [ "$nc" = '(' ]; then
            cur="$cur\$("; i=$((i + 2)); qnest=1; qmode=""
            while [ "$i" -lt "$len" ] && [ "$qnest" -gt 0 ]; do
              c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
              if [ -n "$qmode" ]; then
                if [ "$c" = '\' ] && [ "$qmode" != "'" ] && [ -n "$nc" ]; then
                  if [ "$nc" = $'\n' ]; then i=$((i + 2)); continue; fi
                  cur="$cur$c$nc"; i=$((i + 2)); continue
                fi
                cur="$cur$c"; i=$((i + 1))
                [ "$c" = "$qmode" ] && qmode=""
                continue
              fi
              case "$c" in
                "'"|'"'|'`') qmode="$c"; cur="$cur$c"; i=$((i + 1)) ;;
                '\')
                  if [ "$nc" = $'\n' ]; then i=$((i + 2))
                  elif [ -n "$nc" ]; then cur="$cur$c$nc"; i=$((i + 2))
                  else i=$((i + 1)); fi
                  ;;
                '(') qnest=$((qnest + 1)); cur="$cur$c"; i=$((i + 1)) ;;
                ')') qnest=$((qnest - 1)); cur="$cur$c"; i=$((i + 1)) ;;
                $'\n') cur="$cur\\n"; i=$((i + 1)) ;;
                *) cur="$cur$c"; i=$((i + 1)) ;;
              esac
            done
          elif [ "$c" = '"' ]; then
            i=$((i + 1))
            break
          elif [ "$c" = '\' ]; then
            case "$nc" in
              $'\n') i=$((i + 2)) ;;
              '"'|'\')
                cur="$cur$nc"
                i=$((i + 2))
                ;;
              *)
                cur="$cur\\"
                i=$((i + 1))
                ;;
            esac
          elif [ "$c" = $'\n' ]; then
            cur="$cur\\n"
            i=$((i + 1))
          else
            cur="$cur$c"
            i=$((i + 1))
          fi
        done
        ;;
      '`')
        word_start=0; io_candidate=0
        cur="$cur$c"
        i=$((i + 1))
        while [ "$i" -lt "$len" ]; do
          c="${s:$i:1}"
          nc="${s:$((i + 1)):1}"
          if [ "$c" = '\' ] && [ -n "$nc" ]; then
            if [ "$nc" = $'\n' ]; then
              i=$((i + 2)); continue
            fi
            case "$nc" in '`'|'\'|'$') cur="$cur$c$nc"; i=$((i + 2)); continue ;; esac
          fi
          if [ "$c" = '`' ]; then cur="$cur$c"; i=$((i + 1)); break; fi
          if [ "$c" = $'\n' ]; then cur="$cur\\n"; else cur="$cur$c"; fi
          i=$((i + 1))
        done
        ;;
      '\')
        if [ "$nc" = $'\n' ]; then
          i=$((i + 2))
        elif [ -n "$nc" ]; then
          cur="$cur$nc"; word_start=0; io_candidate=0; word_started=1
          i=$((i + 2))
        else
          i=$((i + 1))
        fi
        ;;
      *)
        cur="$cur$c"
        word_start=0; word_started=1
        case "$c" in [0-9]) : ;; *) io_candidate=0 ;; esac
        i=$((i + 1))
        ;;
    esac
  done
  if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
    h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
  fi
  _hz_emit_word "$cur" "$word_started" "$skip_word" || true
}

# Parse one heredoc declaration beginning at `<<`. The decoded delimiter and
# quote/strip flags are returned in globals; NEXT points just past the delimiter
# word. This is syntax inspection only and never evaluates input.
_hz_parse_heredoc_decl() { # <source> <index-of-first-<>; sets HZ_HD_*
  local s="$1" i=$((2 + $2)) len=${#1} c delim="" quoted=0 strip=0
  if [ "${s:$i:1}" = '-' ]; then strip=1; i=$((i + 1)); fi
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"
    case "$c" in ' '|$'\t') i=$((i + 1)) ;; *) break ;; esac
  done
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"
    case "$c" in
      ' '|$'\t'|$'\n'|';'|'|'|'&') break ;;
      "'"|\")
        local q="$c"
        quoted=1; i=$((i + 1))
        while [ "$i" -lt "$len" ] && [ "${s:$i:1}" != "$q" ]; do
          c="${s:$i:1}"
          if [ "$q" = '"' ] && [ "$c" = '\' ] && [ -n "${s:$((i + 1)):1}" ]; then
            i=$((i + 1)); c="${s:$i:1}"
          fi
          delim="$delim$c"; i=$((i + 1))
        done
        [ "$i" -lt "$len" ] && i=$((i + 1))
        ;;
      '\')
        quoted=1; i=$((i + 1))
        [ "$i" -lt "$len" ] && { delim="$delim${s:$i:1}"; i=$((i + 1)); }
        ;;
      *) delim="$delim$c"; i=$((i + 1)) ;;
    esac
  done
  HZ_HD_DELIM="$delim"; HZ_HD_QUOTED="$quoted"; HZ_HD_STRIP="$strip"; HZ_HD_NEXT="$i"
}

# The nested-command extractor is separate from argv tokenization: command
# substitutions execute even when embedded inside one outer argv. Matching the
# closing parenthesis must still understand comments and heredocs, where a `)`
# is data rather than shell structure.
_hz_extract_dollar_command() { # <source> <index-of-$>; sets HZ_NESTED_BODY/NEXT
  local s="$1" i=$((2 + $2)) len=${#1} depth=1 mode="" c nc body="" word_start=1 comment=0 matched=0
  local start line cmp h
  local -a hd_delims=() hd_strips=()
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ "$comment" = 1 ]; then
      body="$body$c"; i=$((i + 1))
      if [ "$c" = $'\n' ]; then comment=0; word_start=1; fi
      continue
    fi
    if [ -n "$mode" ]; then
      if [ "$c" = '\' ] && [ "$mode" != "'" ] && [ -n "$nc" ]; then
        body="$body$c$nc"; i=$((i + 2)); continue
      fi
      body="$body$c"; i=$((i + 1))
      [ "$c" = "$mode" ] && mode=""
      continue
    fi
    case "$c" in
      "'"|'"') mode="$c"; body="$body$c"; word_start=0; i=$((i + 1)) ;;
      '\')
        if [ -n "$nc" ]; then body="$body$c$nc"; i=$((i + 2)); else i=$((i + 1)); fi
        ;;
      '#')
        if [ "$word_start" = 1 ]; then comment=1; fi
        body="$body$c"; word_start=0; i=$((i + 1))
        ;;
      '<')
        if [ "$nc" = '<' ] && [ "${s:$((i + 2)):1}" != '<' ]; then
          _hz_parse_heredoc_decl "$s" "$i"
          h=${#hd_delims[@]}; hd_delims[$h]="$HZ_HD_DELIM"; hd_strips[$h]="$HZ_HD_STRIP"
          body="$body${s:$i:$((HZ_HD_NEXT - i))}"; i=$HZ_HD_NEXT; word_start=0
        else body="$body$c"; i=$((i + 1)); word_start=0; fi
        ;;
      '`')
        _hz_extract_backtick_command "$s" "$i"
        body="$body${s:$i:$((HZ_NESTED_NEXT - i))}"
        i=$HZ_NESTED_NEXT; word_start=0
        ;;
      $'\n')
        body="$body$c"; i=$((i + 1)); word_start=1
        h=0
        while [ "$h" -lt "${#hd_delims[@]}" ]; do
          while [ "$i" -lt "$len" ]; do
            start=$i
            while [ "$i" -lt "$len" ] && [ "${s:$i:1}" != $'\n' ]; do i=$((i + 1)); done
            line="${s:$start:$((i - start))}"; cmp="$line"
            if [ "${hd_strips[$h]}" = 1 ]; then while [ "${cmp:0:1}" = $'\t' ]; do cmp="${cmp:1}"; done; fi
            body="$body$line"
            [ "$i" -lt "$len" ] && { body="$body"$'\n'; i=$((i + 1)); }
            [ "$cmp" = "${hd_delims[$h]}" ] && break
          done
          h=$((h + 1))
        done
        hd_delims=(); hd_strips=()
        ;;
      ' '|$'\t'|';'|'|'|'&') body="$body$c"; word_start=1; i=$((i + 1)) ;;
      '(') depth=$((depth + 1)); body="$body$c"; word_start=1; i=$((i + 1)) ;;
      ')')
        depth=$((depth - 1)); i=$((i + 1))
        if [ "$depth" -eq 0 ]; then matched=1; break; fi
        body="$body$c"; word_start=0
        ;;
      *) body="$body$c"; word_start=0; i=$((i + 1)) ;;
    esac
  done
  HZ_NESTED_BODY="$body"
  HZ_NESTED_NEXT="$i"
  HZ_NESTED_MATCHED="$matched"
}

_hz_extract_backtick_command() { # <source> <index-of-backtick>
  local s="$1" i=$((1 + $2)) len=${#1} c nc body="" matched=0
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ "$c" = '\' ] && [ -n "$nc" ]; then
      # Escaped backticks are how legacy syntax nests another backtick command.
      if [ "$nc" = '`' ]; then body="$body$nc"; else body="$body$c$nc"; fi
      i=$((i + 2)); continue
    fi
    i=$((i + 1))
    if [ "$c" = '`' ]; then matched=1; break; fi
    body="$body$c"
  done
  HZ_NESTED_BODY="$body"
  HZ_NESTED_NEXT="$i"
  HZ_NESTED_MATCHED="$matched"
}

# Arithmetic expansion is not shell command syntax: `<<` is a shift operator,
# quotes are arithmetic tokens, and only explicit `$()` / backticks execute.
_hz_extract_arithmetic() { # <source> <index-of-$>; sets HZ_NESTED_BODY/NEXT/MATCHED
  local s="$1" i=$((3 + $2)) len=${#1} depth=1 mode="" c nc body="" next matched=0
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ -n "$mode" ]; then
      if [ "$c" = '\' ] && [ "$mode" != "'" ] && [ -n "$nc" ]; then body="$body$c$nc"; i=$((i + 2)); continue; fi
      body="$body$c"; [ "$c" = "$mode" ] && mode=""; i=$((i + 1)); continue
    fi
    case "$c" in
      "'"|'"') mode="$c"; body="$body$c"; i=$((i + 1)) ;;
      '\') if [ -n "$nc" ]; then body="$body$c$nc"; i=$((i + 2)); else i=$((i + 1)); fi ;;
      '$')
        if [ "$nc" = '(' ] && [ "${s:$((i + 2)):1}" != '(' ]; then
          _hz_extract_dollar_command "$s" "$i"; next=$HZ_NESTED_NEXT
          body="$body${s:$i:$((next - i))}"; i=$next
        else body="$body$c"; i=$((i + 1)); fi ;;
      '`')
        _hz_extract_backtick_command "$s" "$i"; next=$HZ_NESTED_NEXT
        body="$body${s:$i:$((next - i))}"; i=$next ;;
      '(') depth=$((depth + 1)); body="$body$c"; i=$((i + 1)) ;;
      ')')
        if [ "$depth" -eq 1 ] && [ "$nc" = ')' ]; then i=$((i + 2)); matched=1; break; fi
        [ "$depth" -gt 1 ] && depth=$((depth - 1))
        body="$body$c"; i=$((i + 1)) ;;
      *) body="$body$c"; i=$((i + 1)) ;;
    esac
  done
  HZ_NESTED_BODY="$body"; HZ_NESTED_NEXT="$i"; HZ_NESTED_MATCHED="$matched"
}

_hz_extract_arithmetic_command() { # <source> <index-of-first-(>
  local prefixed="\$$1"
  _hz_extract_arithmetic "$prefixed" "$2"
  HZ_NESTED_NEXT=$((HZ_NESTED_NEXT - 1))
}

_hz_extract_bracket_word() { # <source> <index-of-[>; sets HZ_NESTED_BODY/NEXT/MATCHED
  local s="$1" i=$((1 + $2)) len=${#1} depth=1 mode="" c nc body="" next matched=0
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ -n "$mode" ]; then
      if [ "$c" = '\' ] && [ "$mode" != "'" ] && [ -n "$nc" ]; then body="$body$c$nc"; i=$((i + 2)); continue; fi
      body="$body$c"; [ "$c" = "$mode" ] && mode=""; i=$((i + 1)); continue
    fi
    case "$c" in
      "'"|'"') mode="$c"; body="$body$c"; i=$((i + 1)) ;;
      '\') if [ -n "$nc" ]; then body="$body$c$nc"; i=$((i + 2)); else i=$((i + 1)); fi ;;
      '$')
        if [ "$nc" = '(' ] && [ "${s:$((i + 2)):1}" != '(' ]; then _hz_extract_dollar_command "$s" "$i"; next=$HZ_NESTED_NEXT; body="$body${s:$i:$((next - i))}"; i=$next
        else body="$body$c"; i=$((i + 1)); fi ;;
      '`') _hz_extract_backtick_command "$s" "$i"; next=$HZ_NESTED_NEXT; body="$body${s:$i:$((next - i))}"; i=$next ;;
      '[') depth=$((depth + 1)); body="$body$c"; i=$((i + 1)) ;;
      ']')
        depth=$((depth - 1)); i=$((i + 1))
        if [ "$depth" -eq 0 ]; then matched=1; break; fi
        body="$body$c" ;;
      *) body="$body$c"; i=$((i + 1)) ;;
    esac
  done
  HZ_NESTED_BODY="$body"; HZ_NESTED_NEXT="$i"; HZ_NESTED_MATCHED="$matched"
}

_hz_extract_braced_word() { # <source> <index-of-$>; sets HZ_NESTED_BODY/NEXT/MATCHED
  local s="$1" i=$((2 + $2)) len=${#1} depth=1 mode="" c nc body="" next matched=0
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ -n "$mode" ]; then
      if [ "$c" = '\' ] && [ "$mode" != "'" ] && [ -n "$nc" ]; then body="$body$c$nc"; i=$((i + 2)); continue; fi
      body="$body$c"
      [ "$c" = "$mode" ] && mode=""
      i=$((i + 1)); continue
    fi
    case "$c" in
      "'"|'"') mode="$c"; body="$body$c"; i=$((i + 1)) ;;
      '\') if [ -n "$nc" ]; then body="$body$c$nc"; i=$((i + 2)); else i=$((i + 1)); fi ;;
      '$')
        if [ "$nc" = '(' ] && [ "${s:$((i + 2)):1}" != '(' ]; then
          _hz_extract_dollar_command "$s" "$i"; next=$HZ_NESTED_NEXT
          body="$body${s:$i:$((next - i))}"; i=$next
        else body="$body$c"; i=$((i + 1)); fi ;;
      '`')
        _hz_extract_backtick_command "$s" "$i"; next=$HZ_NESTED_NEXT
        body="$body${s:$i:$((next - i))}"; i=$next ;;
      '{') depth=$((depth + 1)); body="$body$c"; i=$((i + 1)) ;;
      '}')
        depth=$((depth - 1)); i=$((i + 1))
        if [ "$depth" -eq 0 ]; then matched=1; break; fi
        body="$body$c" ;;
      *) body="$body$c"; i=$((i + 1)) ;;
    esac
  done
  HZ_NESTED_BODY="$body"; HZ_NESTED_NEXT="$i"; HZ_NESTED_MATCHED="$matched"
}

# Append executable substitutions found in an unquoted heredoc body. Quote
# characters are ordinary heredoc data; only backslash can suppress `$` / `` ` ``.
_hz_append_nested_command() {
  HZ_NESTED_COMMANDS[$HZ_NESTED_COUNT]="$1"
  HZ_NESTED_COUNT=$((HZ_NESTED_COUNT + 1))
}

_hz_collect_heredoc_expansions() {
  local s="$1" i=0 len=${#1} c nc body next
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ "$c" = '\' ] && [ -n "$nc" ]; then i=$((i + 2)); continue; fi
    if [ "$c" = '$' ] && [ "$nc" = '(' ]; then
      if [ "${s:$((i + 2)):1}" = '(' ]; then i=$((i + 3)); continue; fi
      _hz_extract_dollar_command "$s" "$i"; body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && { _hz_append_nested_command "$body"; _hz_collect_nested_scan "$body"; }
      i="$next"; continue
    fi
    if [ "$c" = '$' ] && [ "$nc" = '{' ]; then
      _hz_extract_braced_word "$s" "$i"; body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && _hz_collect_heredoc_expansions "$body"
      i="$next"; continue
    fi
    if [ "$c" = '`' ]; then
      _hz_extract_backtick_command "$s" "$i"; body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && { _hz_append_nested_command "$body"; _hz_collect_nested_scan "$body"; }
      i="$next"; continue
    fi
    i=$((i + 1))
  done
}

_hz_collect_nested_scan() {
  local s="$1" i=0 len=${#1} mode="" c nc body next word_start=1 comment=0
  local start line cmp hd_body h
  local -a hd_delims=() hd_quoted=() hd_strips=()
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ "$comment" = 1 ]; then
      if [ "$c" = $'\n' ]; then comment=0; word_start=1; fi
      i=$((i + 1)); continue
    fi
    if [ "$mode" = "'" ]; then
      [ "$c" = "'" ] && mode=""
      i=$((i + 1)); continue
    fi
    if [ "$mode" = '"' ]; then
      if [ "$c" = '\' ] && [ -n "$nc" ]; then i=$((i + 2)); continue; fi
      if [ "$c" = '"' ]; then mode=""; word_start=0; i=$((i + 1)); continue; fi
    else
      if [ "$c" = '\' ] && [ -n "$nc" ]; then i=$((i + 2)); continue; fi
      if [ "$c" = "'" ]; then mode="'"; word_start=0; i=$((i + 1)); continue; fi
      if [ "$c" = '"' ]; then mode='"'; word_start=0; i=$((i + 1)); continue; fi
      if [ "$c" = '#' ] && [ "$word_start" = 1 ]; then comment=1; i=$((i + 1)); continue; fi
      if [ "$c" = '<' ] && [ "$nc" = '<' ] && [ "${s:$((i + 2)):1}" != '<' ]; then
        _hz_parse_heredoc_decl "$s" "$i"
        h=${#hd_delims[@]}; hd_delims[$h]="$HZ_HD_DELIM"; hd_quoted[$h]="$HZ_HD_QUOTED"; hd_strips[$h]="$HZ_HD_STRIP"
        i=$HZ_HD_NEXT; word_start=0; continue
      fi
    fi
    if [ "$c" = '$' ] && [ "$nc" = '(' ]; then
      # `$((...))` is arithmetic expansion, not a command. Continue scanning
      # its contents because an explicit nested `$()` or backtick still runs.
      if [ "${s:$((i + 2)):1}" = '(' ]; then
        _hz_extract_arithmetic "$s" "$i"; body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
        [ "$HZ_NESTED_MATCHED" = 1 ] && _hz_collect_heredoc_expansions "$body"
        i="$next"; continue
      fi
      _hz_extract_dollar_command "$s" "$i"
      body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && { _hz_append_nested_command "$body"; _hz_collect_nested_scan "$body"; }
      i="$next"; continue
    fi
    if [ "$c" = '$' ] && [ "$nc" = '{' ]; then
      _hz_extract_braced_word "$s" "$i"; body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && _hz_collect_heredoc_expansions "$body"
      i="$next"; continue
    fi
    if [ -z "$mode" ] && [ "$c" = '(' ] && [ "$nc" = '(' ]; then
      _hz_extract_arithmetic_command "$s" "$i"; body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && _hz_collect_heredoc_expansions "$body"
      i="$next"; continue
    fi
    if [ -z "$mode" ] && [ "$c" = '[' ]; then
      _hz_extract_bracket_word "$s" "$i"; body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && _hz_collect_heredoc_expansions "$body"
      i="$next"; continue
    fi
    if [ -z "$mode" ] && { [ "$c" = '<' ] || [ "$c" = '>' ]; } && [ "$nc" = '(' ]; then
      _hz_extract_dollar_command "$s" "$i"
      body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && { _hz_append_nested_command "$body"; _hz_collect_nested_scan "$body"; }
      i="$next"; continue
    fi
    if [ "$c" = '`' ]; then
      _hz_extract_backtick_command "$s" "$i"
      body="$HZ_NESTED_BODY"; next="$HZ_NESTED_NEXT"
      [ "$HZ_NESTED_MATCHED" = 1 ] && { _hz_append_nested_command "$body"; _hz_collect_nested_scan "$body"; }
      i="$next"; continue
    fi
    if [ "$c" = $'\n' ]; then
      i=$((i + 1)); word_start=1; h=0
      while [ "$h" -lt "${#hd_delims[@]}" ]; do
        hd_body=""
        while [ "$i" -lt "$len" ]; do
          start=$i
          while [ "$i" -lt "$len" ] && [ "${s:$i:1}" != $'\n' ]; do i=$((i + 1)); done
          line="${s:$start:$((i - start))}"; cmp="$line"
          if [ "${hd_strips[$h]}" = 1 ]; then while [ "${cmp:0:1}" = $'\t' ]; do cmp="${cmp:1}"; done; fi
          if [ "$cmp" = "${hd_delims[$h]}" ]; then [ "$i" -lt "$len" ] && i=$((i + 1)); break; fi
          hd_body="$hd_body$line"; [ "$i" -lt "$len" ] && { hd_body="$hd_body"$'\n'; i=$((i + 1)); }
        done
        [ "${hd_quoted[$h]}" = 1 ] || _hz_collect_heredoc_expansions "$hd_body"
        h=$((h + 1))
      done
      hd_delims=(); hd_quoted=(); hd_strips=(); continue
    fi
    case "$c" in ' '|$'\t'|';'|'|'|'&'|'('|')') word_start=1 ;; *) word_start=0 ;; esac
    i=$((i + 1))
  done
}

# hz_collect_nested_commands "<command>" populates HZ_NESTED_COMMANDS. Each
# array element is one exact body, so embedded newlines are not record separators.
hz_collect_nested_commands() {
  HZ_NESTED_COMMANDS=()
  HZ_NESTED_COUNT=0
  _hz_collect_nested_scan "$1"
}

# Compatibility stream API. Multiline bodies remain inherently ambiguous here;
# decision adapters should use hz_collect_nested_commands and iterate the array.
hz_nested_commands() {
  local body i=0
  hz_collect_nested_commands "$1"
  while [ "$i" -lt "$HZ_NESTED_COUNT" ]; do
    body="${HZ_NESTED_COMMANDS[$i]}"
    printf '%s\n' "$body"
    i=$((i + 1))
  done
}

# hz_collect_command_segments "<command>" populates HZ_COMMAND_SEGMENTS with
# exact raw top-level segments. Quoted/substitution newlines and heredoc bodies
# stay inside their containing segment.
hz_collect_command_segments() {
  local s="$1" i=0 len=${#1} mode="" c nc cur="" body next start line cmp h comment=0 word_start=1
  local -a hd_delims=() hd_strips=()
  HZ_COMMAND_SEGMENTS=()
  HZ_COMMAND_SEGMENT_COUNT=0
  while [ "$i" -lt "$len" ]; do
    c="${s:$i:1}"; nc="${s:$((i + 1)):1}"
    if [ "$comment" = 1 ]; then
      if [ "$c" = $'\n' ]; then
        HZ_COMMAND_SEGMENTS[$HZ_COMMAND_SEGMENT_COUNT]="$cur"; HZ_COMMAND_SEGMENT_COUNT=$((HZ_COMMAND_SEGMENT_COUNT + 1)); cur=""; comment=0; word_start=1
      else
        cur="$cur$c"
      fi
      i=$((i + 1)); continue
    fi
    if [ "$mode" = "'" ]; then cur="$cur$c"; [ "$c" = "'" ] && mode=""; i=$((i + 1)); continue; fi
    if [ "$mode" = '"' ]; then
      if [ "$c" = '\' ] && [ -n "$nc" ]; then cur="$cur$c$nc"; i=$((i + 2)); continue; fi
      if [ "$c" = '"' ]; then mode=""; cur="$cur$c"; i=$((i + 1)); continue; fi
      if [ "$c" = '$' ] && [ "$nc" = '(' ]; then
        if [ "${s:$((i + 2)):1}" = '(' ]; then _hz_extract_arithmetic "$s" "$i"
        else _hz_extract_dollar_command "$s" "$i"; fi
        next=$HZ_NESTED_NEXT; cur="$cur${s:$i:$((next - i))}"; i=$next; continue
      fi
      if [ "$c" = '$' ] && [ "$nc" = '{' ]; then
        _hz_extract_braced_word "$s" "$i"; next=$HZ_NESTED_NEXT; cur="$cur${s:$i:$((next - i))}"; i=$next; continue
      fi
      if [ "$c" = '`' ]; then _hz_extract_backtick_command "$s" "$i"; next=$HZ_NESTED_NEXT; cur="$cur${s:$i:$((next - i))}"; i=$next; continue; fi
      cur="$cur$c"; i=$((i + 1)); continue
    fi
    case "$c" in
      "'"|'"') mode="$c"; cur="$cur$c"; word_start=0; i=$((i + 1)) ;;
      '\') cur="$cur$c$nc"; word_start=0; i=$((i + 2)) ;;
      '#')
        if [ "$word_start" = 1 ]; then comment=1; fi
        cur="$cur$c"; word_start=0; i=$((i + 1)) ;;
      '$')
        if [ "$nc" = '(' ]; then
          if [ "${s:$((i + 2)):1}" = '(' ]; then _hz_extract_arithmetic "$s" "$i"
          else _hz_extract_dollar_command "$s" "$i"; fi
          next=$HZ_NESTED_NEXT; cur="$cur${s:$i:$((next - i))}"; i=$next
        elif [ "$nc" = '{' ]; then _hz_extract_braced_word "$s" "$i"; next=$HZ_NESTED_NEXT; cur="$cur${s:$i:$((next - i))}"; i=$next
        else cur="$cur$c"; word_start=0; i=$((i + 1)); fi ;;
      '<'|'>')
        if [ "$nc" = '(' ]; then _hz_extract_dollar_command "$s" "$i"; next=$HZ_NESTED_NEXT; cur="$cur${s:$i:$((next - i))}"; i=$next
        elif [ "$c" = '<' ] && [ "$nc" = '<' ] && [ "${s:$((i + 2)):1}" != '<' ]; then
          _hz_parse_heredoc_decl "$s" "$i"; h=${#hd_delims[@]}; hd_delims[$h]="$HZ_HD_DELIM"; hd_strips[$h]="$HZ_HD_STRIP"
          cur="$cur${s:$i:$((HZ_HD_NEXT - i))}"; i=$HZ_HD_NEXT
        else cur="$cur$c"; word_start=0; i=$((i + 1)); fi ;;
      '`') _hz_extract_backtick_command "$s" "$i"; next=$HZ_NESTED_NEXT; cur="$cur${s:$i:$((next - i))}"; i=$next ;;
      $'\n')
        cur="$cur$c"; i=$((i + 1)); h=0
        while [ "$h" -lt "${#hd_delims[@]}" ]; do
          while [ "$i" -lt "$len" ]; do
            start=$i; while [ "$i" -lt "$len" ] && [ "${s:$i:1}" != $'\n' ]; do i=$((i + 1)); done
            line="${s:$start:$((i - start))}"; cmp="$line"
            if [ "${hd_strips[$h]}" = 1 ]; then while [ "${cmp:0:1}" = $'\t' ]; do cmp="${cmp:1}"; done; fi
            cur="$cur$line"; [ "$i" -lt "$len" ] && { cur="$cur"$'\n'; i=$((i + 1)); }
            [ "$cmp" = "${hd_delims[$h]}" ] && break
          done
          h=$((h + 1))
        done
        if [ "${#hd_delims[@]}" -gt 0 ]; then hd_delims=(); hd_strips=(); HZ_COMMAND_SEGMENTS[$HZ_COMMAND_SEGMENT_COUNT]="$cur"; HZ_COMMAND_SEGMENT_COUNT=$((HZ_COMMAND_SEGMENT_COUNT + 1)); cur=""
        else HZ_COMMAND_SEGMENTS[$HZ_COMMAND_SEGMENT_COUNT]="${cur%$'\n'}"; HZ_COMMAND_SEGMENT_COUNT=$((HZ_COMMAND_SEGMENT_COUNT + 1)); cur=""; fi
        word_start=1
        ;;
      ';'|'&'|'|')
        HZ_COMMAND_SEGMENTS[$HZ_COMMAND_SEGMENT_COUNT]="$cur"; HZ_COMMAND_SEGMENT_COUNT=$((HZ_COMMAND_SEGMENT_COUNT + 1)); cur=""
        if { [ "$c" = '&' ] && [ "$nc" = '&' ]; } || { [ "$c" = '|' ] && { [ "$nc" = '|' ] || [ "$nc" = '&' ]; }; }; then i=$((i + 2)); else i=$((i + 1)); fi
        word_start=1
        ;;
      ' '|$'\t') cur="$cur$c"; word_start=1; i=$((i + 1)) ;;
      *) cur="$cur$c"; word_start=0; i=$((i + 1)) ;;
    esac
  done
  if [ -n "$cur" ]; then
    # shellcheck disable=SC2034 # public result array consumed by sourced callers
    HZ_COMMAND_SEGMENTS[$HZ_COMMAND_SEGMENT_COUNT]="$cur"
    HZ_COMMAND_SEGMENT_COUNT=$((HZ_COMMAND_SEGMENT_COUNT + 1))
  fi
}

# hz_first_segment "<command>" -> print only argv records before the first
# top-level command boundary. Centralizes the stop rule for push/destructive.
hz_first_segment() {
  local tok
  while IFS= read -r tok; do
    [ -z "$tok" ] && break
    printf '%s\n' "$tok"
  done <<EOF
$(hz_tokenize "$1")
EOF
}

# env -S uses its own split-string escape where `\_` represents a blank.
# Decode that escape before feeding the value back through the shell tokenizer.
hz_env_split_text() {
  local value="$1"
  value="${value//\\_/ }"
  printf '%s' "$value"
}

# hz_command_argv "<simple segment>" -> normalized executable argv, one token
# per line. Shell control reserved words and common direct-exec wrappers are
# removed before anchored classifiers inspect the command head.
hz_command_argv() {
  local tok state='scan' skip_value=0
  while IFS= read -r tok; do
    if [ "$state" = emit ]; then printf '%s\n' "$tok"; continue; fi
    if [ "$skip_value" = 1 ]; then skip_value=0; continue; fi
    case "$state" in
      scan)
        case "$tok" in
          case) state='case_subject'; continue ;;
          if|then|elif|else|while|until|do|'!'|'{'|'}') continue ;;
          *')') continue ;; # case pattern head after a `|` segment boundary
          *=*) continue ;;
          sudo) state='sudo'; continue ;;
          env) state='env'; continue ;;
          command) state='command'; continue ;;
          exec) state='exec'; continue ;;
          time) state='time'; continue ;;
          nohup) state='nohup'; continue ;;
          *) state='emit'; printf '%s\n' "$tok" ;;
        esac
        ;;
      case_subject) state='case_in' ;;
      case_in) [ "$tok" = in ] && state='case_pattern' ;;
      case_pattern) state='scan' ;;
      sudo)
        case "$tok" in
          --) state='scan' ;;
          -u|-g|-h|-p|-r|-t|-C|-D|-T|--user|--group|--host|--prompt|--role|--type|--chdir)
            skip_value=1 ;;
          -*) : ;;
          *=*) : ;;
          *) state='scan'
             case "$tok" in sudo|env|command|exec|time|nohup) state="$tok" ;; *) state='emit'; printf '%s\n' "$tok" ;; esac ;;
        esac
        ;;
      env)
        case "$tok" in
          --) state='scan' ;;
          -u|-C|-P|--unset|--chdir) skip_value=1 ;;
          -S|--split-string) state='env_split' ;;
          -S?*) hz_command_argv "$(hz_env_split_text "${tok#-S}")"; state='emit' ;;
          --split-string=*) hz_command_argv "$(hz_env_split_text "${tok#--split-string=}")"; state='emit' ;;
          --unset=*|--chdir=*|-*) : ;;
          *=*) : ;;
          *) state='scan'
             case "$tok" in sudo|env|command|exec|time|nohup) state="$tok" ;; *) state='emit'; printf '%s\n' "$tok" ;; esac ;;
        esac
        ;;
      env_split)
        hz_command_argv "$(hz_env_split_text "$tok")"
        state='emit'
        ;;
      command)
        case "$tok" in
          -v|-V) return 0 ;; # query only; does not execute the named command
          --) state='scan' ;;
          -p) : ;;
          *) state='scan'
             case "$tok" in sudo|env|command|exec|time|nohup) state="$tok" ;; *) state='emit'; printf '%s\n' "$tok" ;; esac ;;
        esac
        ;;
      exec)
        case "$tok" in
          --) state='scan' ;;
          -a) skip_value=1 ;;
          -*) : ;;
          *) state='scan'
             case "$tok" in sudo|env|command|exec|time|nohup) state="$tok" ;; *) state='emit'; printf '%s\n' "$tok" ;; esac ;;
        esac
        ;;
      time)
        case "$tok" in -p|--) [ "$tok" = -- ] && state='scan' ;; *) state='emit'; printf '%s\n' "$tok" ;; esac
        ;;
      nohup)
        case "$tok" in --) state='scan' ;; *) state='emit'; printf '%s\n' "$tok" ;; esac
        ;;
    esac
  done <<EOF
$(hz_first_segment "$1")
EOF
}
