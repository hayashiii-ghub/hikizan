#!/usr/bin/env bash
# Hookの入力解析に必要なjqが利用できるか確認する。
# 判定不能なPRマージを黙って許可しないために使う。
hz_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  printf 'hikizan hook: jq not found; failing closed rather than skipping safety checks. install jq to proceed.\n' >&2
  exit 2
}
