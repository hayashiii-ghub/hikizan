#!/usr/bin/env bash
# `gh pr merge`の軽い分類器が通常の入力と承認印を識別できるか確認する。
# PR作成や説明文を誤ってマージ操作や承認として扱わないために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/pr-merge.sh"

hit() { if hz_is_pr_merge "$1"; then echo yes; else echo no; fi; }
approved() { if hz_has_merge_approval "$1"; then echo yes; else echo no; fi; }

assert_eq "plain gh pr merge" "yes" "$(hit 'gh pr merge 123 --squash')"
assert_eq "compound gh pr merge" "yes" "$(hit 'cd /tmp && gh pr merge 123')"
assert_eq "nested gh pr merge" "yes" "$(hit 'echo "$(gh pr merge 123)"')"
assert_eq "wrapped gh pr merge" "yes" "$(hit 'env GH_HOST=x gh pr merge 123')"
assert_eq "direct environment assignment is merge" "yes" "$(hit 'GH_HOST=x gh pr merge 123')"
assert_eq "quoted command tokens are outside the normal path" "no" "$(hit '"gh" "pr" "merge" 123')"
assert_eq "quoted mention is not a command" "no" "$(hit 'echo "gh pr merge 123"')"
assert_eq "single-quoted mention is not a command" "no" "$(hit "echo 'gh pr merge 123'")"
assert_eq "PR creation is not merge" "no" "$(hit 'gh pr create --draft')"
assert_eq "local git merge is not PR merge" "no" "$(hit 'git merge feature')"
assert_eq "GitHub API is outside the supported path" "no" "$(hit 'gh api -X PUT repos/o/r/pulls/1/merge')"
assert_eq "ordinary argument sequence is not a command" "no" "$(hit 'echo gh pr merge 123')"
assert_eq "approval marker before merge" "yes" "$(approved 'HIKIZAN_MERGE_APPROVED=1 gh pr merge 123')"
assert_eq "env approval marker before merge" "yes" "$(approved 'env HIKIZAN_MERGE_APPROVED=1 gh pr merge 123')"
assert_eq "approval marker among assignments" "yes" "$(approved 'env GH_HOST=x HIKIZAN_MERGE_APPROVED=1 GH_DEBUG=0 gh pr merge 123')"
assert_eq "approval marker mention is not approval" "no" "$(approved 'echo HIKIZAN_MERGE_APPROVED=1 gh pr merge 123')"
assert_eq "different approval value is not approval" "no" "$(approved 'HIKIZAN_MERGE_APPROVED=0 gh pr merge 123')"

hz_test_summary
