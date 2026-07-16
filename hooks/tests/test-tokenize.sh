#!/usr/bin/env bash
# Unit tests for hooks/scripts/lib/tokenize.sh — the quote-aware tokenizer
# pre-pr-create.sh relies on so quoted strings never leak flag-like substrings
# into the flag scan.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/tokenize.sh"

tok() { hz_tokenize "$1" | paste -sd'|' - ; }
tok_records() {
  hz_tokenize "$1" | awk '{ if (length($0) == 0) print "<boundary>"; else print }' | paste -sd'|' -
}

assert_eq "plain flags"                 "gh|pr|create|--draft"            "$(tok 'gh pr create --draft')"
assert_eq "double-quoted --draft mention" "gh|pr|create|--title|add -d flag docs" "$(tok 'gh pr create --title "add -d flag docs"')"
assert_eq "single-quoted --draft mention" "gh|pr|create|--title|notes on --draft" "$(tok "gh pr create --title 'notes on --draft'")"
assert_eq "backslash-escaped space"     "a b|c"                            "$(tok 'a\ b c')"
assert_eq "double-quote unescape"       'echo|a "quoted" word'             "$(tok 'echo "a \"quoted\" word"')"
assert_eq "single token, no split"      "--reviewer=alice"                 "$(tok '--reviewer=alice')"
assert_eq "unterminated quote"          "unterminated|quote here"          "$(tok 'unterminated "quote here')"

# Unquoted shell control operators are emitted as an empty boundary record.
# Consumers can then stop or reset state without confusing quoted/escaped
# operator-shaped arguments with syntax.
assert_eq "spaced && boundary"           "echo|a|<boundary>|echo|b"           "$(tok_records 'echo a && echo b')"
assert_eq "adjacent && boundary"         "echo|a|<boundary>|echo|b"           "$(tok_records 'echo a&&echo b')"
assert_eq "adjacent || boundary"         "echo|a|<boundary>|echo|b"           "$(tok_records 'echo a||echo b')"
assert_eq "adjacent semicolon boundary"  "echo|a|<boundary>|echo|b"           "$(tok_records 'echo a;echo b')"
assert_eq "adjacent pipe boundary"       "echo|a|<boundary>|grep|b"           "$(tok_records 'echo a|grep b')"
assert_eq "adjacent ampersand boundary"  "echo|a|<boundary>|echo|b"           "$(tok_records 'echo a&echo b')"
assert_eq "pipe-amp boundary"            "echo|a|<boundary>|tee|out"          "$(tok_records 'echo a|&tee out')"
assert_eq "newline boundary"             "echo|a|<boundary>|echo|b"           "$(tok_records $'echo a\necho b')"

assert_eq "quoted operator stays an argument"  "echo|&&|tail"                   "$(tok_records 'echo "&&" tail')"
assert_eq "escaped operator stays an argument" "echo|&&|tail"                   "$(tok_records 'echo \&\& tail')"
assert_eq "fd duplication is omitted, not a boundary"   "echo|x"                 "$(tok 'echo x 2>&1')"
assert_eq "combined redirect is omitted, not a boundary" "echo|x"                "$(tok 'echo x &>out')"
assert_eq "clobber redirect is omitted, not a boundary"  "echo|x"                "$(tok 'echo x >|out')"
assert_eq "line continuation is removed"        "gh|pr|create|--title|x"         \
  "$(tok_records $'gh pr \\\ncreate --title x')"
assert_eq "quoted multiline token stays one record" 'rm|-r|foo\n\nbar|-f|target' \
  "$(tok_records $'rm -r "foo\n\nbar" -f target')"
assert_eq "command substitution operators stay nested" 'rm|-r|$(printf x&&printf y)|-f|target' \
  "$(tok_records 'rm -r $(printf x&&printf y) -f target')"
assert_eq "process substitution operators stay nested" 'cat|<(printf x|sed s/x/y/)|tail' \
  "$(tok_records 'cat <(printf x|sed s/x/y/) tail')"
assert_eq "backtick operators stay nested" 'rm|-r|`printf x&&printf y`|-f|target' \
  "$(tok_records 'rm -r `printf x&&printf y` -f target')"
assert_eq "attached redirection is omitted from argv" 'git|push|--force|origin|main' \
  "$(tok_records 'git >/tmp/out push --force origin main')"
assert_eq "separate redirection target is omitted from argv" 'git|push|--force|origin|main' \
  "$(tok_records 'git > /tmp/out push --force origin main')"
assert_eq "fd duplication is omitted from argv" 'git|push|--force|origin|main' \
  "$(tok_records 'git 2>&1 push --force origin main')"
assert_eq "combined redirection is omitted from argv" 'git|push|--force|origin|main' \
  "$(tok_records 'git &>out push --force origin main')"
assert_eq "comment text is omitted" 'gh|pr|create|--title|x' \
  "$(tok_records 'gh pr create --title x # --draft')"
assert_eq "word-internal hash remains data" 'echo|x#y' \
  "$(tok_records 'echo x#y')"
assert_eq "parameter expansion operators stay nested" 'rm|-r|${v:-a&&b}|-f|target' \
  "$(tok_records 'rm -r ${v:-a&&b} -f target')"
assert_eq "backtick redirection target is omitted" 'git|reset|--hard' \
  "$(tok_records 'git >`printf /tmp/out&&printf x` reset --hard')"
assert_eq "continued line preserves comment start" 'gh|pr|create|--title|x' \
  "$(tok_records $'gh pr create --title x \\\n# --draft')"
assert_eq "heredoc body is omitted" 'cat|<boundary>' \
  "$(tok_records $'cat <<EOF\ngh pr create --title x\nEOF')"
assert_eq "escaped backtick stays inside substitution" 'rm|-r|`printf "x\`y" && printf z`|-f|target' \
  "$(tok_records 'rm -r `printf "x\`y" && printf z` -f target')"
assert_eq "multiple heredoc bodies are omitted in order" 'cat|<boundary>' \
  "$(tok_records $'cat <<A <<B\nB\nA\ngh pr create --title x\nB')"
assert_eq "quoted numeric argv is not an io number" 'git|2|reset|--hard' \
  "$(tok_records 'git "2">out reset --hard')"
assert_eq "escaped numeric argv is not an io number" 'git|2|reset|--hard' \
  "$(tok_records 'git \2>out reset --hard')"
assert_eq "ANSI-C quoted flag is decoded" 'git|push|--force|origin|main' \
  "$(tok_records "git push \$'--force' origin main")"
assert_eq "ANSI-C hex escape is decoded" 'git|push|--force|origin|main' \
  "$(tok_records "git push \$'--fo\\x72ce' origin main")"

hz_test_summary
