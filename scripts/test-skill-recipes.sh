#!/usr/bin/env bash
# スキルに記載したGitの比較範囲とpush手順を、一時リポジトリで検査する。
# 文書どおりの操作で変更範囲やPRの比較元が崩れないことを確かめる。
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
remote="$tmp/remote.git"
repo="$tmp/repo"

git init --bare -q "$remote"
git init -q "$repo"
git -C "$repo" config user.name hikizan-test
git -C "$repo" config user.email hikizan-test.invalid
printf 'base\n' > "$repo/base.txt"
git -C "$repo" add base.txt
git -C "$repo" commit -qm base
git -C "$repo" branch -M main
git -C "$repo" remote add origin "$remote"
git -C "$repo" push -qu origin main
git --git-dir="$remote" symbolic-ref HEAD refs/heads/main
git -C "$repo" remote set-head origin -a >/dev/null

git -C "$repo" switch -q -c feature --track origin/main
printf 'feature\n' > "$repo/feature.txt"
git -C "$repo" add feature.txt
git -C "$repo" commit -qm feature

base="$(git -C "$repo" merge-base HEAD origin/main)"
review_range="$base...HEAD"
[ "$(git -C "$repo" diff --name-only "$review_range")" = 'feature.txt' ] || {
  echo '✘ committed review range omitted the feature change'
  exit 1
}

if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/feature; then
  echo '✘ test precondition failed: remote feature branch already exists'
  exit 1
fi
[ "$(git -C "$repo" rev-parse --abbrev-ref '@{u}')" = 'origin/main' ] || {
  echo '✘ test precondition failed: feature should initially track the PR base'
  exit 1
}
git -C "$repo" fetch -q origin
git -C "$repo" push -qu --set-upstream origin HEAD:refs/heads/feature
[ "$(git -C "$repo" rev-parse --abbrev-ref '@{u}')" = 'origin/feature' ] || {
  echo '✘ explicit first push did not configure the upstream'
  exit 1
}
git -C "$repo" push -q --dry-run origin HEAD:refs/heads/feature

# A feature upstream is a push target, never the PR base. Re-resolve the base
# from the selected remote's default branch after the first push.
remote_head="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD)"
pr_base="${remote_head#origin/}"
[ "$pr_base" = 'main' ] || {
  echo '✘ PR base drifted from remote default after first push'
  exit 1
}
base="$(git -C "$repo" merge-base HEAD "origin/$pr_base")"
[ -n "$(git -C "$repo" diff --name-only "$base...HEAD")" ] || {
  echo '✘ PR range became empty after first push'
  exit 1
}

valid_remote() {
  candidate="$1"
  case "$candidate" in
    ''|-*) return 1 ;;
  esac
  git -C "$repo" remote | grep -Fxq -- "$candidate"
}
valid_remote origin || {
  echo '✘ valid push remote was rejected'
  exit 1
}
if valid_remote --all; then
  echo '✘ option-shaped remote passed validation'
  exit 1
fi
valid_branch() {
  candidate="$1"
  case "$candidate" in
    ''|-*) return 1 ;;
  esac
  git -C "$repo" check-ref-format --branch "$candidate" >/dev/null
}
valid_branch feature || {
  echo '✘ valid branch failed target validation'
  exit 1
}
if valid_branch -mirror; then
  echo '✘ option-shaped branch passed Git ref validation'
  exit 1
fi

# A fork push remote and canonical PR remote have deliberately different
# main histories: fork=A, upstream=A+B, and feature=A+B+F. Only the
# remote-qualified upstream base yields scope F.
fork_remote="$tmp/fork.git"
canonical_remote="$tmp/canonical.git"
fork_repo="$tmp/fork-repo"
git init --bare -q "$fork_remote"
git init --bare -q "$canonical_remote"
git init -q "$fork_repo"
git -C "$fork_repo" config user.name hikizan-test
git -C "$fork_repo" config user.email hikizan-test.invalid
git -C "$fork_repo" remote add origin "$fork_remote"
git -C "$fork_repo" remote add upstream "$canonical_remote"
printf 'A\n' > "$fork_repo/a.txt"
git -C "$fork_repo" add a.txt
git -C "$fork_repo" commit -qm A
git -C "$fork_repo" branch -M main
git -C "$fork_repo" push -qu origin main
git -C "$fork_repo" push -qu upstream main
printf 'B\n' > "$fork_repo/b.txt"
git -C "$fork_repo" add b.txt
git -C "$fork_repo" commit -qm B
git -C "$fork_repo" push -qu upstream main
git -C "$fork_repo" switch -q -c feature
git -C "$fork_repo" config branch.feature.remote upstream
git -C "$fork_repo" config branch.feature.pushRemote origin
printf 'F\n' > "$fork_repo/f.txt"
git -C "$fork_repo" add f.txt
git -C "$fork_repo" commit -qm F
git -C "$fork_repo" push -qu origin feature
git -C "$fork_repo" fetch -q origin
git -C "$fork_repo" fetch -q upstream

# Push-target selection follows Git's explicit push configuration before the
# tracking remote. A fork feature may track upstream/main while pushing to origin.
push_remote="$(git -C "$fork_repo" config --get branch.feature.pushRemote ||
  git -C "$fork_repo" config --get remote.pushDefault ||
  git -C "$fork_repo" config --get branch.feature.remote || true)"
[ "$push_remote" = 'origin' ] || {
  echo '✘ fork push target ignored branch.pushRemote precedence'
  exit 1
}

git -C "$fork_repo" branch -D main >/dev/null
if git -C "$fork_repo" show-ref --verify --quiet refs/heads/main; then
  echo '✘ fork test precondition failed: local main still exists'
  exit 1
fi
fork_base="$(git -C "$fork_repo" merge-base HEAD upstream/main)"
[ "$(git -C "$fork_repo" diff --name-only "$fork_base...HEAD")" = 'f.txt' ] || {
  echo '✘ fork PR range did not use the remote-qualified canonical base'
  exit 1
}
wrong_base="$(git -C "$fork_repo" merge-base HEAD origin/main)"
[ "$(git -C "$fork_repo" diff --name-only "$wrong_base...HEAD")" = $'b.txt\nf.txt' ] || {
  echo '✘ fork test precondition failed: push and PR bases are indistinguishable'
  exit 1
}

# BRANCH_SNAPSHOT must include committed, staged, unstaged, and untracked
# files in one review descriptor.
printf 'staged\n' > "$repo/staged.txt"
git -C "$repo" add staged.txt
printf 'worktree\n' >> "$repo/base.txt"
printf 'untracked\n' > "$repo/untracked.txt"
tracked="$(git -C "$repo" diff --name-only "$base" --)"
for expected in base.txt feature.txt staged.txt; do
  printf '%s\n' "$tracked" | grep -qxF "$expected" || {
    echo "✘ branch snapshot omitted tracked state: $expected"
    exit 1
  }
done
[ "$(git -C "$repo" ls-files --others --exclude-standard)" = 'untracked.txt' ] || {
  echo '✘ branch snapshot omitted untracked state'
  exit 1
}

echo '✔ skill recipes preserve mixed scope, PR base, and explicit push'
