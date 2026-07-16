#!/usr/bin/env bash
# Regression test for lib/metrics.sh synthetic-session_id write guard.
#
# A non-empty session_id that is not the accepted UUID form (^[0-9a-f]{8}-) is a
# hand-crafted manual-test payload and must NOT be appended to the metrics
# file. Otherwise ad-hoc hook testing without HIKIZAN_METRICS_DIR pollutes real
# aggregation (36 such lines were purged 2026-07-06). Empty session_id
# (genuinely unavailable) and real UUID-form ids are still recorded. Same regex
# the aggregation examples used to filter on at read time, now enforced on write.

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"

# shellcheck source=../scripts/lib/metrics.sh
source "$DIR/../scripts/lib/metrics.sh"

# log_lines <session_id> — log one event into a fresh dir, echo the line count.
log_lines() {
  HIKIZAN_METRICS_DIR="$(mktemp -d)"
  export HIKIZAN_METRICS_DIR
  hikizan_metrics_log hook_fired pre-push none allow "$1"
  local f="$HIKIZAN_METRICS_DIR/metrics.jsonl"
  if [ -f "$f" ]; then wc -l < "$f" | tr -d ' '; else printf '0'; fi
}

# 1. synthetic short ids (the observed pollution: x/s/test/s1/t) are dropped.
assert_eq "synthetic 'x' dropped"    "0" "$(log_lines x)"
assert_eq "synthetic 's1' dropped"   "0" "$(log_lines s1)"
assert_eq "synthetic 'test' dropped" "0" "$(log_lines test)"

# 2. real harness UUID-form ids are recorded (write path still works for real data).
assert_eq "real UUID recorded"          "1" "$(log_lines 0a1b2c3d-4e5f-6789-abcd-ef0123456789)"
assert_eq "fixture UUID-shaped recorded" "1" "$(log_lines deadbeef-0000-0000-0000-000000000000)"

# 3. empty session_id (genuinely unavailable) is still recorded.
assert_eq "empty session_id recorded" "1" "$(log_lines '')"

# 4. implementation comments and the public matrix list only emitted values.
STALE=$(grep -Ehc 'submodule_unpushed|"warn"|session_id":"abc123"|CC session id' \
  "$DIR/../scripts/lib/metrics.sh" "$DIR/../conditions.md" | awk '{sum += $1} END {print sum}')
assert_eq "metrics schema docs contain no stale values" "0" "$STALE"

hz_test_summary
