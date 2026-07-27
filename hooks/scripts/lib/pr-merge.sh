#!/usr/bin/env bash
# 通常の`gh pr merge`と、明示承認後の一時的な承認印を識別する。
# 永続状態を持たず、未承認のマージだけを人間へ戻すために使う。

hz_is_pr_merge() {
  printf '%s\n' "$1" | grep -Eq \
    '(^|[;&|()][[:space:]]*)(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:];&|()]+[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+merge([[:space:];&|()]|$)'
}

hz_has_merge_approval() {
  printf '%s\n' "$1" | grep -Eq \
    '(^|[;&|()][[:space:]]*)(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:];&|()]+[[:space:]]+)*HIKIZAN_MERGE_APPROVED=1[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:];&|()]+[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+merge([[:space:];&|()]|$)'
}
