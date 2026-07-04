#!/usr/bin/env bash
# PostToolUse observation hook for Bash. Records ONLY the executions that
# match a floor target class (destructive / force-equivalent push to a
# protected branch / non-draft gh pr create without a reviewer) — not every
# Bash command — so we can later see (a) how often an `ask` from
# pre-destructive is actually followed by execution (approval rate) and
# (b) whether a class the floors mean to deny ever executes anyway (bypass
# evidence). PostToolUse cannot change the outcome (the tool already ran) so
# this hook never emits a decision and always exits 0 — observation only.
# If jq is absent, this degrades to a no-op (same policy as
# session-context.sh): an observability gap must never break a tool call.

set -uo pipefail
HERE="$(dirname "$0")"

# shellcheck source=lib/metrics.sh
source "$HERE/lib/metrics.sh" 2>/dev/null || hikizan_metrics_log() { :; }
# shellcheck source=lib/destructive.sh
source "$HERE/lib/destructive.sh"
# shellcheck source=lib/push-parse.sh
source "$HERE/lib/push-parse.sh"
# shellcheck source=lib/pr-create.sh
source "$HERE/lib/pr-create.sh"

command -v jq >/dev/null 2>&1 || exit 0

JSON=$(cat) || exit 0
COMMAND=$(printf '%s' "$JSON" | jq -r '.tool_input.command // ""') || exit 0
SESSION_ID=$(printf '%s' "$JSON" | jq -r '.session_id // ""') || exit 0

[ -n "$COMMAND" ] || exit 0

CWD=$(printf '%s' "$JSON" | jq -r '.cwd // ""') || CWD=""
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null || true

# 1. irreversible op executed -> would have been an `ask`
LABEL=$(hz_destructive_label "$COMMAND")
if [ -n "$LABEL" ]; then
  hikizan_metrics_log command_executed post-command destructive ask "$SESSION_ID"
  exit 0
fi

# 2. force-equivalent push to a protected branch executed -> would have
# been a `block` (the pre-push floor denies this).
if [ "$(hz_git_subcommand "$COMMAND")" = "push" ] && hikizan_push_is_forceful "$COMMAND"; then
  PUSHDIR=$(hz_push_dir "$COMMAND")
  [ -n "$PUSHDIR" ] && [ ! -d "$PUSHDIR" ] && PUSHDIR=""
  if [ -n "$PUSHDIR" ]; then BRANCH=$(git -C "$PUSHDIR" branch --show-current 2>/dev/null || true)
  else BRANCH=$(git branch --show-current 2>/dev/null || true); fi
  HIT=$(hikizan_push_protected_hit "$COMMAND" "$BRANCH") || HIT=""
  if [ -n "$HIT" ]; then
    hikizan_metrics_log command_executed post-command force_protected block "$SESSION_ID"
    exit 0
  fi
fi

# 3. non-draft PR without reviewer executed -> would have been a `block`.
if hz_is_pr_create "$COMMAND" && hz_prcreate_needs_review "$COMMAND"; then
  hikizan_metrics_log command_executed post-command no_draft_no_reviewer block "$SESSION_ID"
  exit 0
fi

exit 0
