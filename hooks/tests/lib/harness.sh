#!/usr/bin/env bash
# Minimal assert harness for hikizan hook tests (bash 3.2 compatible, no deps).
#
# Each test file sources this, then calls assert_* helpers. The runner
# (run.sh) sources each test file in a subshell and inspects the exported
# counters PASS / FAIL printed by hz_test_summary.

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

# hz_run_hook <script> <command> [cwd] — run a hook script with a synthetic
# PreToolUse payload. Sets HZ_OUT (stdout), HZ_ERR (stderr), HZ_CODE (exit).
# shellcheck disable=SC2034  # HZ_OUT / HZ_CODE / HZ_ERR are read by the sourcing test files
hz_run_hook() {
  local script="$1" cmd="$2" cwd="${3:-}"
  local payload errf
  payload=$(jq -nc --arg c "$cmd" --arg w "$cwd" \
    '{tool_input:{command:$c}, cwd:$w, session_id:"test"}')
  errf="$(mktemp 2>/dev/null || echo /tmp/hz_err.$$)"
  HZ_OUT=$(printf '%s' "$payload" | bash "$script" 2>"$errf")
  HZ_CODE=$?
  HZ_ERR=$(cat "$errf" 2>/dev/null)
  rm -f "$errf"
}

# hz_decision_of <stdout-json> — extract permissionDecision, default "allow".
hz_decision_of() {
  if [ -z "$1" ]; then echo allow; return; fi
  printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || echo allow
}

# hz_test_summary — print machine-readable counters the runner aggregates.
hz_test_summary() {
  printf 'HZ_RESULT pass=%s fail=%s\n' "$HZ_PASS" "$HZ_FAIL"
}
