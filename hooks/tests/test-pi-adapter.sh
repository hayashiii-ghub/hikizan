#!/usr/bin/env bash
# piアダプターの起動と短縮コマンドを、外部機能を代替して確認する。
# 追加機能を保ちながら、起動処理や進行表示の重複を戻さないために使う。
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
node --test "$DIR/pi-adapter.test.mjs"
assert_exit "pi adapter lifecycle and commands" 0 "$?"
hz_test_summary
