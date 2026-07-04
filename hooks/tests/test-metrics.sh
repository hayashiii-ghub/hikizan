#!/usr/bin/env bash
# Regression test for lib/metrics.sh size-based rotation. Without this, the
# metrics file can grow unbounded — HIKIZAN_METRICS_MAX_BYTES pins the
# threshold and behaviour at both sides of it.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"

# shellcheck source=../scripts/lib/metrics.sh
source "$DIR/../scripts/lib/metrics.sh"

# 1. file already over threshold -> rotate before the new line is appended.
HIKIZAN_METRICS_DIR="$(mktemp -d)"
export HIKIZAN_METRICS_DIR
HIKIZAN_METRICS_MAX_BYTES=200
export HIKIZAN_METRICS_MAX_BYTES

FILE="$HIKIZAN_METRICS_DIR/metrics.jsonl"
ROTATED="$FILE.1"

# ~300 bytes of dummy content, well over the 200-byte threshold.
printf '{"dummy":"line","padding":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}\n' \
  > "$FILE"
printf '{"dummy":"line2","padding":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}\n' \
  >> "$FILE"
printf '{"dummy":"line3","padding":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}\n' \
  >> "$FILE"
DUMMY_SIZE=$(wc -c < "$FILE" | tr -d ' ')
[ "$DUMMY_SIZE" -gt 200 ] || printf '  WARN: fixture is only %s bytes, expected >200\n' "$DUMMY_SIZE"

hikizan_metrics_log hook_fired pre-push none allow "test"

assert_eq "over-threshold: metrics.jsonl.1 exists after rotation" "0" "$([ -f "$ROTATED" ] && echo 0 || echo 1)"
assert_eq "over-threshold: metrics.jsonl has exactly 1 line" "1" "$(wc -l < "$FILE" | tr -d ' ')"

# 2. file under threshold -> no rotation triggered by this call, and an
# existing .1 generation is left untouched (not re-created / overwritten).
HIKIZAN_METRICS_DIR="$(mktemp -d)"
export HIKIZAN_METRICS_DIR
FILE="$HIKIZAN_METRICS_DIR/metrics.jsonl"
ROTATED="$FILE.1"

printf '{"seed":"generation"}\n' > "$ROTATED"
BEFORE_ROTATED_CONTENT="$(cat "$ROTATED")"
printf '{"small":"line"}\n' > "$FILE"

hikizan_metrics_log hook_fired pre-push none allow "test"

assert_eq "under-threshold: metrics.jsonl.1 unchanged" "$BEFORE_ROTATED_CONTENT" "$(cat "$ROTATED")"
assert_eq "under-threshold: metrics.jsonl has exactly 2 lines (no rotation, plain append)" "2" "$(wc -l < "$FILE" | tr -d ' ')"

hz_test_summary
