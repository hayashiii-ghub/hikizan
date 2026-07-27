#!/usr/bin/env bash
# hooks/testsの各テストを個別に実行し、結果を集計する。
# 人とCIが同じ入口でHook全体を検証するために使う。
# 使い方: bash hooks/tests/run.sh [テスト名]

set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

FILTER="${1:-}"
TOTAL_PASS=0
TOTAL_FAIL=0
FILES=0

for t in "$DIR"/test-*.sh; do
  [ -e "$t" ] || continue
  name="$(basename "$t" .sh)"
  name="${name#test-}"
  if [ -n "$FILTER" ] && [ "$name" != "$FILTER" ]; then
    continue
  fi
  FILES=$((FILES + 1))
  printf '── %s ──\n' "$name"
  out="$(bash "$t" 2>&1)"
  # echo everything except the machine-readable result line
  printf '%s\n' "$out" | grep -v '^HZ_RESULT ' || true
  res="$(printf '%s\n' "$out" | grep '^HZ_RESULT ' | tail -1)"
  p="$(printf '%s' "$res" | sed -n 's/.*pass=\([0-9]*\).*/\1/p')"
  f="$(printf '%s' "$res" | sed -n 's/.*fail=\([0-9]*\).*/\1/p')"
  [ -z "$p" ] && p=0
  [ -z "$f" ] && f=0
  if [ -z "$res" ]; then
    printf '  (no HZ_RESULT — test crashed before summary)\n'
    f=$((f + 1))
  fi
  printf '  %s: pass=%s fail=%s\n' "$name" "$p" "$f"
  TOTAL_PASS=$((TOTAL_PASS + p))
  TOTAL_FAIL=$((TOTAL_FAIL + f))
done

printf '\n=== total: %s file(s), pass=%s fail=%s ===\n' "$FILES" "$TOTAL_PASS" "$TOTAL_FAIL"
[ "$TOTAL_FAIL" -eq 0 ]
