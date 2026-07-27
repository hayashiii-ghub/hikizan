#!/usr/bin/env bash
# `gh pr merge`の軽い分類器が通常の入力を識別できるか確認する。
# PR作成や説明文を誤ってマージ操作として扱わないために使う。

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib/harness.sh"
. "$DIR/../scripts/lib/pr-merge.sh"

hit() { if hz_is_pr_merge "$1"; then echo yes; else echo no; fi; }

assert_eq "plain gh pr merge" "yes" "$(hit 'gh pr merge 123 --squash')"
assert_eq "compound gh pr merge" "yes" "$(hit 'cd /tmp && gh pr merge 123')"
assert_eq "nested gh pr merge" "yes" "$(hit 'echo "$(gh pr merge 123)"')"
assert_eq "wrapped gh pr merge" "yes" "$(hit 'env GH_HOST=x gh pr merge 123')"
assert_eq "quoted command tokens are outside the normal path" "no" "$(hit '"gh" "pr" "merge" 123')"
assert_eq "quoted mention is not a command" "no" "$(hit 'echo "gh pr merge 123"')"
assert_eq "single-quoted mention is not a command" "no" "$(hit "echo 'gh pr merge 123'")"
assert_eq "PR creation is not merge" "no" "$(hit 'gh pr create --draft')"
assert_eq "local git merge is not PR merge" "no" "$(hit 'git merge feature')"
assert_eq "GitHub API is outside the supported path" "no" "$(hit 'gh api -X PUT repos/o/r/pulls/1/merge')"
assert_eq "ordinary argument sequence is not a command" "no" "$(hit 'echo gh pr merge 123')"

hz_test_summary
