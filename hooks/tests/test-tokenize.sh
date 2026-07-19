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
nested() { hz_nested_commands "$1" | paste -sd'|' -; }
argv() { hz_command_argv "$1" | paste -sd'|' -; }
unresolved() { if hz_command_has_unresolved_env_split "$1"; then echo yes; else echo no; fi; }
collect_nested_count() { hz_collect_nested_commands "$1"; printf '%s' "${#HZ_NESTED_COMMANDS[@]}"; }
collect_segment_count() { hz_collect_command_segments "$1"; printf '%s' "${#HZ_COMMAND_SEGMENTS[@]}"; }

assert_eq "plain flags"                 "gh|pr|create|--draft"            "$(tok 'gh pr create --draft')"
assert_eq "double-quoted --draft mention" "gh|pr|create|--title|add -d flag docs" "$(tok 'gh pr create --title "add -d flag docs"')"
assert_eq "single-quoted --draft mention" "gh|pr|create|--title|notes on --draft" "$(tok "gh pr create --title 'notes on --draft'")"
assert_eq "backslash-escaped space"     "a b|c"                            "$(tok 'a\ b c')"
assert_eq "double-quote unescape"       'echo|a "quoted" word'             "$(tok 'echo "a \"quoted\" word"')"
assert_eq "single token, no split"      "--reviewer=alice"                 "$(tok '--reviewer=alice')"
assert_eq "unterminated quote"          "unterminated|quote here"          "$(tok 'unterminated "quote here')"
assert_eq "empty quoted argv keeps its position" 'git|push|-o|__hikizan_empty_arg__|--delete|origin|main' \
  "$(tok 'git push -o "" --delete origin main')"
assert_eq "empty single-quoted argv keeps its position" 'gh|__hikizan_empty_arg__|pr|create' \
  "$(tok "gh '' pr create")"
assert_eq "normalize env wrapper" 'git|push|--force|origin|main' \
  "$(argv 'env FOO=x git push --force origin main')"
assert_eq "normalize env split-string command" 'git|push|--force|origin|main' \
  "$(argv 'env -S "git push --force origin main"')"
assert_eq "normalize attached env split-string command" 'git|push|--force|origin|main' \
  "$(argv 'env -S"git push --force origin main"')"
assert_eq "normalize long env split-string command" 'git|push|--force|origin|main' \
  "$(argv 'env --split-string="git push --force origin main"')"
assert_eq "normalize env split-string blank escape" 'git|push|--force|origin|main' \
  "$(argv "env -S 'git\\_push\\_--force\\_origin\\_main'")"
assert_eq "expand assigned env split-string command head" 'git|push|--force|origin|main' \
  "$(argv "CMD=git env -S '\${CMD} push --force origin main'")"
assert_eq "mark unresolved env split-string command head" '__hikizan_unresolved_env_split__' \
  "$(argv "env -S '\${HIKIZAN_TEST_UNDEFINED} push --force origin main'")"
assert_eq "find unresolved env split after earlier segment" 'yes' \
  "$(unresolved "rm -rf /tmp/x; env -S '\${HIKIZAN_TEST_UNDEFINED} harmless'")"
assert_eq "find nested unresolved env split" 'yes' \
  "$(unresolved "echo \"\$(env -S '\${HIKIZAN_TEST_UNDEFINED} harmless')\"")"
assert_eq "normalize BSD env utility path" 'git|push|--force|origin|main' \
  "$(argv 'env -P /usr/bin git push --force origin main')"
assert_eq "normalize sudo options" 'rm|-rf|/tmp/x' \
  "$(argv 'sudo -n -u root rm -rf /tmp/x')"
assert_eq "normalize sudo environment assignment" 'rm|-rf|/tmp/x' \
  "$(argv 'sudo FOO=x rm -rf /tmp/x')"
assert_eq "normalize command separator" 'git|push|--force|origin|main' \
  "$(argv 'command -- git push --force origin main')"
assert_eq "command query does not execute" '' "$(argv 'command -v git')"
assert_eq "normalize reserved command head" 'git|push|--force|origin|main' \
  "$(argv 'then ! exec git push --force origin main')"
assert_eq "normalize case arm command head" 'git|push|--force|origin|main' \
  "$(argv 'case x in x) git push --force origin main')"
assert_eq "extract double-quoted command substitution" 'git push --force origin main' \
  "$(nested 'echo "$(git push --force origin main)"')"
assert_eq "extract backtick command substitution" 'git reset --hard' \
  "$(nested 'echo `git reset --hard`')"
assert_eq "ignore single-quoted substitution text" '' \
  "$(nested "echo '\$(rm -rf /tmp/x)'")"
assert_eq "single quote inside double quotes stays literal" 'rm -rf /tmp/x' \
  "$(nested 'echo "'\''$(rm -rf /tmp/x)'\''"')"
assert_eq "arithmetic expansion is not a command" '' \
  "$(nested 'echo $((git push --force origin main))')"
assert_eq "arithmetic shift cannot hide command substitution" \
  'git push --force origin main; echo 0' \
  "$(nested $'echo $((1 << "2"\n + $(git push --force origin main; echo 0)))')"
assert_eq "arithmetic can contain explicit nested command" 'printf 1' \
  "$(nested 'echo $((1 + $(printf 1)))')"
assert_eq "parameter word cannot fake a heredoc to hide command substitution" \
  'git push --force origin main; echo ok' \
  "$(nested $'echo ${unset:-x <<\'2\'\n$(git push --force origin main; echo ok)\n2\n}')"
assert_eq "arithmetic command cannot fake a heredoc" \
  'git push --force origin main; echo 0' \
  "$(nested $'((1 << \'2\'\n + $(git push --force origin main; echo 0)))')"
assert_eq "array subscript cannot fake a heredoc" \
  'git push --force origin main; echo 0' \
  "$(nested $'a[1 << \'2\'\n + $(git push --force origin main; echo 0)]=x')"
assert_eq "process substitution body is executable" 'printf x|rm -rf /tmp/x' \
  "$(nested 'diff <(printf x) <(rm -rf /tmp/x)')"
assert_eq "quoted process substitution is literal" '' \
  "$(nested 'printf %s "<(rm -rf /tmp/x)"')"
assert_eq "extract recursively nested substitution" 'echo $(rm -rf /tmp/x)|rm -rf /tmp/x' \
  "$(nested 'printf %s "$(echo $(rm -rf /tmp/x))"')"
assert_eq "comment marker is not executable" '' \
  "$(nested 'echo ok # $(rm -rf /tmp/x)')"
assert_eq "unmatched command substitution is not executable" '' \
  "$(nested 'echo $(rm -rf /tmp/x')"
assert_eq "backtick paren does not close outer substitution" \
  'printf %s `echo )`; git push --force origin main|echo )' \
  "$(nested 'echo "$(printf %s `echo )`; git push --force origin main)"')"
assert_eq "word-internal hash does not start a comment" 'rm -rf /tmp/x' \
  "$(nested 'echo x#y $(rm -rf /tmp/x)')"
assert_eq "quoted heredoc does not expand substitutions" '' \
  "$(nested $'cat <<\'EOF\'\n$(rm -rf /tmp/x)\nEOF')"
assert_eq "unquoted heredoc expands command substitution" 'rm -rf /tmp/x' \
  "$(nested $'cat <<EOF\n$(rm -rf /tmp/x)\nEOF')"
assert_eq "unquoted heredoc expands backticks" 'git reset --hard' \
  "$(nested $'cat <<EOF\n`git reset --hard`\nEOF')"
assert_eq "comment close-paren does not truncate command substitution" 1 \
  "$(collect_nested_count $'echo "$(echo x # )\ngit push --force origin main\n)"')"
hz_collect_nested_commands $'echo "$(echo x # )\ngit push --force origin main\n)"'
assert_eq "multiline nested body is preserved as one array element" \
  $'echo x # )\ngit push --force origin main\n' "${HZ_NESTED_COMMANDS[0]}"
assert_eq "quoted heredoc close-paren does not truncate command substitution" 1 \
  "$(collect_nested_count $'echo "$(cat <<\'EOF\'\n)\nEOF\ngit push --force origin main\n)"')"
hz_collect_nested_commands $'echo "$(cat <<\'EOF\'\n)\nEOF\ngit push --force origin main\n)"'
assert_eq "nested heredoc body remains inside collected command" \
  $'cat <<\'EOF\'\n)\nEOF\ngit push --force origin main\n' "${HZ_NESTED_COMMANDS[0]}"

assert_eq "raw command segment collector finds both segments" 2 \
  "$(collect_segment_count $'printf "%s\n" "line one\nline two"; git push --force origin main')"
hz_collect_command_segments $'printf "%s\n" "line one\nline two"; git push --force origin main'
assert_eq "quoted multiline argv stays in one raw segment" \
  $'printf "%s\n" "line one\nline two"' "${HZ_COMMAND_SEGMENTS[0]}"
assert_eq "later raw segment is preserved" ' git push --force origin main' \
  "${HZ_COMMAND_SEGMENTS[1]}"
assert_eq "comment operators do not create command segments" 1 \
  "$(collect_segment_count $'echo ok # ; git push --force origin main\n')"
hz_collect_command_segments $'echo ok # ; git push --force origin main\n'
assert_eq "comment text remains in its non-executable segment" \
  'echo ok # ; git push --force origin main' "${HZ_COMMAND_SEGMENTS[0]}"

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
