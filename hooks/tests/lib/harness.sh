#!/usr/bin/env bash
# Hookテストで共通利用する最小限のアサーション関数を提供する。
# 各テストの結果形式を揃え、run.shで集計できるようにするために使う。

HZ_PASS=0
HZ_FAIL=0

# assert_eq <desc> <expected> <actual>
assert_eq() {
  if [ "$2" = "$3" ]; then
    HZ_PASS=$((HZ_PASS + 1))
  else
    HZ_FAIL=$((HZ_FAIL + 1))
    printf '  FAIL: %s\n        expected: [%s]\n        actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

# assert_exit <desc> <expected_code> <actual_code>
assert_exit() {
  assert_eq "$1 (exit code)" "$2" "$3"
}

# assert_contains <desc> <needle> <haystack>
assert_contains() {
  case "$3" in
    *"$2"*) HZ_PASS=$((HZ_PASS + 1)) ;;
    *)
      HZ_FAIL=$((HZ_FAIL + 1))
      printf '  FAIL: %s\n        expected to contain: [%s]\n        actual:              [%s]\n' "$1" "$2" "$3"
      ;;
  esac
}

# hz_test_summary — print machine-readable counters the runner aggregates.
hz_test_summary() {
  printf 'HZ_RESULT pass=%s fail=%s\n' "$HZ_PASS" "$HZ_FAIL"
}
