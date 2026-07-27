#!/usr/bin/env bash
# 通常の`gh pr merge`を軽い文字列検査で識別する。
# セキュリティ境界を作らず、マージの誤操作だけを人間へ戻すために使う。

hz_is_pr_merge() {
  printf '%s\n' "$1" | grep -Eq \
    '(^|[;&|()][[:space:]]*)(env([[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:];&|()]+)*[[:space:]]+)?gh[[:space:]]+pr[[:space:]]+merge([[:space:];&|()]|$)'
}
