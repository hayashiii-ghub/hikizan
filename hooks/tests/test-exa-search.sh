#!/usr/bin/env bash
# pi用Exaクライアントの低課金検索と停止境界を確認する。
# 外部APIを使わず、キー欠落や402で意図せず検索を継続しないために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"

output="$(node --test "$DIR/exa-client.test.mjs" 2>&1)"
status=$?
assert_exit "Exa client tests pass" 0 "$status"
if [ "$status" -ne 0 ]; then
	printf '%s\n' "$output"
fi

hz_test_summary
