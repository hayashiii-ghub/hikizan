#!/usr/bin/env bash
# Unit tests for hooks/scripts/lib/tokenize.sh — the quote-aware tokenizer
# pre-pr-create.sh relies on so quoted strings never leak flag-like substrings
# into the flag scan.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/tokenize.sh"

tok() { hz_tokenize "$1" | paste -sd'|' - ; }

assert_eq "plain flags"                 "gh|pr|create|--draft"            "$(tok 'gh pr create --draft')"
assert_eq "double-quoted --draft mention" "gh|pr|create|--title|add -d flag docs" "$(tok 'gh pr create --title "add -d flag docs"')"
assert_eq "single-quoted --draft mention" "gh|pr|create|--title|notes on --draft" "$(tok "gh pr create --title 'notes on --draft'")"
assert_eq "backslash-escaped space"     "a b|c"                            "$(tok 'a\ b c')"
assert_eq "double-quote unescape"       'echo|a "quoted" word'             "$(tok 'echo "a \"quoted\" word"')"
assert_eq "single token, no split"      "--reviewer=alice"                 "$(tok '--reviewer=alice')"
assert_eq "unterminated quote"          "unterminated|quote here"          "$(tok 'unterminated "quote here')"

hz_test_summary
