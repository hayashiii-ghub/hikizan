#!/usr/bin/env bash
# piの本番変更ゲートが対象操作だけを実行前に検出することを確認する。
# 通常の開発コマンドを妨げず、公開・配布・本番変更の見逃しを減らすために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"

output="$(node --test "$DIR/production-risk.test.mjs" "$DIR/production-guard.test.mjs" 2>&1)"
status=$?
assert_exit "production risk tests pass" 0 "$status"
if [ "$status" -ne 0 ]; then
	printf '%s\n' "$output"
fi

hz_test_summary
