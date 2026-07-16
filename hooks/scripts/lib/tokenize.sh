#!/usr/bin/env bash
# hz_tokenize "<command>" -> print one token per line, honouring shell quoting.
# An empty line is a typed command-boundary record for an unquoted control
# operator (`&&`, `||`, `;`, `|`, `|&`, `&`) or an inter-command newline.
# Empty quoted arguments are omitted, so consumers can distinguish syntax
# from quoted/escaped operator-shaped words without exposing raw operators.
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
#   - empty tokens (e.g. a bare '') are never printed
hz_tokenize() {
  local s="$1" i=0 len c nc cur="" have_segment=0 nest=0 brace=0 top_group=0
  local word_start=1 want_redir=0 skip_word=0 target_started=0 opener="" io_candidate=1
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
      if [ -n "$cur" ]; then
        if [ "$skip_word" = 0 ]; then
          if [ "$io_candidate" = 0 ]; then printf '%s\n' "$cur"; have_segment=1; fi
        fi
      fi
      cur=""; skip_word=0; target_started=0; io_candidate=1

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
          if [ -n "$cur" ] && [ "$skip_word" = 0 ]; then printf '%s\n' "$cur"; have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1
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
          if [ -n "$cur" ] && [ "$skip_word" = 0 ]; then printf '%s\n' "$cur"; have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1
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
          if [ -n "$cur" ] && [ "$skip_word" = 0 ]; then printf '%s\n' "$cur"; have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1
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
          if [ -n "$cur" ] && [ "$skip_word" = 0 ]; then printf '%s\n' "$cur"; have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1
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
          if [ -n "$cur" ] && [ "$skip_word" = 0 ]; then printf '%s\n' "$cur"; have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1
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
          cur="$cur$c"; nest=$((nest + 1)); word_start=1; io_candidate=0
        fi
        i=$((i + 1))
        ;;
      ')')
        if [ "$nest" -gt 0 ]; then
          cur="$cur$c"; nest=$((nest - 1)); word_start=0; io_candidate=0
        elif [ "$brace" = 0 ] && [ "$top_group" -gt 0 ]; then
          if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
            h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
            heredoc_pending=0; heredoc_strip=0
          fi
          if [ -n "$cur" ] && [ "$skip_word" = 0 ]; then printf '%s\n' "$cur"; have_segment=1; fi
          cur=""; skip_word=0; target_started=0; io_candidate=1
          if [ "$have_segment" = 1 ]; then printf '\n'; have_segment=0; fi
          top_group=$((top_group - 1)); word_start=1
        else
          cur="$cur$c"; word_start=0; io_candidate=0
        fi
        i=$((i + 1))
        ;;
      '$')
        if [ "$nc" = "'" ]; then
          raw=""; word_start=0; io_candidate=0; i=$((i + 2))
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
          cur="$cur\${"; brace=$((brace + 1)); word_start=0; io_candidate=0; i=$((i + 2))
        else
          cur="$cur$c"; word_start=0; io_candidate=0; i=$((i + 1))
        fi
        ;;
      '}')
        cur="$cur$c"
        [ "$brace" -gt 0 ] && brace=$((brace - 1))
        word_start=0; io_candidate=0
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
        word_start=0; io_candidate=0
        i=$((i + 1))
        while [ "$i" -lt "$len" ]; do
          c="${s:$i:1}"
          i=$((i + 1))
          [ "$c" = "'" ] && break
          if [ "$c" = $'\n' ]; then cur="$cur\\n"; else cur="$cur$c"; fi
        done
        ;;
      '"')
        word_start=0; io_candidate=0
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
          cur="$cur$nc"; word_start=0; io_candidate=0
          i=$((i + 2))
        else
          i=$((i + 1))
        fi
        ;;
      *)
        cur="$cur$c"
        word_start=0
        case "$c" in [0-9]) : ;; *) io_candidate=0 ;; esac
        i=$((i + 1))
        ;;
    esac
  done
  if [ "$target_started" = 1 ] && [ "$heredoc_pending" = 1 ]; then
    h=${#heredoc_delims[@]}; heredoc_delims[$h]="$cur"; heredoc_strips[$h]="$heredoc_strip"
  fi
  [ -n "$cur" ] && [ "$skip_word" = 0 ] && printf '%s\n' "$cur"
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
