#!/usr/bin/env bash
# piからClaudeへ委譲するACP起動条件を確認する。
# サブスク利用がAPI課金や書き込み許可へ変わらないようにするために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"

output="$(node --test "$DIR/claude-delegate.test.mjs" 2>&1)"
status=$?
assert_exit "pi Claude delegate tests pass" 0 "$status"
if [ "$status" -ne 0 ]; then
  printf '%s\n' "$output"
fi

hz_test_summary
