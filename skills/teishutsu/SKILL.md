---
name: teishutsu
description: "Use this skill when the user wants to submit a pull request — including the phrasings PR出す, PR提出, PR ready, PR open する, submit. Handles the full submission flow: remote state check, submodule-first ordering, parent commit, cwd-aware gh pr create. Activates after implementation is complete and ready to ship, even when the user just says 提出する or 出す without explicit PR wording."
license: MIT
when_to_use: "PR提出, PR出す, PR ready, submission, PR open"
metadata:
  version: "0.1.0"
---

# teishutsu (提出)

```
🌲 Using /teishutsu for [purpose taken from trigger context].
```

「実装完了 → PR open まで」を運ぶ skill。submission 工程の漏れ (リモート状態未確認 / submodule 順序ミス / cwd ミスでの gh コマンド / reviewer 未指定の本番 PR) を防ぐ。本文は `sadoku` の PR 説明文 mode と handoff 関係: 本 skill は提出プロセス、`sadoku` は本文ドラフトを担当する。

## Step 0: worktree 検出

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
[ "$GIT_DIR" != "$GIT_COMMON" ] && echo "(worktree内: $(git branch --show-current))"
```

## 起動トリガー

| 発話トリガー | 状態トリガー |
|---|---|
| `PR出す` / `PR提出` / `PR ready` / `提出して` | `kouchiku` 計画実行モードの完了報告直後 |

状態トリガーは誤発火回避のため、検出後に確認 prompt を 1 行挟む (`実装完了です。PR を出しますか?`)。

## 提出フロー (4 step、順序を守る)

### Step 1: リモート状態確認

```bash
git fetch --all
BRANCH=$(git branch --show-current)
git log "HEAD..origin/$BRANCH" --oneline 2>/dev/null
```

- リモート先行 (= 別経路で commit されている) があれば「別実装の存在」を警告して両案残すか確認
- non-fast-forward は pre-push hook が最終的に block するが、teishutsu は先に検出してユーザに選択肢 (pull --rebase / 別 branch / abort) を提示する
- 失敗時は次に進まない

### Step 2: submodule に変更があれば submodule 側から処理

```bash
git submodule status --recursive
```

- submodule に未 commit / 未 push がある場合:
  1. submodule 内で commit message ドラフトを teishutsu 内で 1 段落生成 → user 承認
  2. submodule で commit + push
- 親 commit より submodule push を **必ず先**にする (post-commit hook が submodule 未 push を警告するが、warning では巻き戻せないため teishutsu 側で事前解消する)

### Step 3: parent commit

- 親 repo で `git add` (submodule pointer 更新含む) → commit message ドラフト → user 承認 → commit
- push (pre-push hook が non-ff / force-to-protected を block する。block 時は Step 1 に戻って原因解消)

### Step 4: PR 作成

**cwd を `gh pr create` 直前で必ず確認** — submodule と親 repo を取り違える事故を防ぐ最重要 step:

```bash
pwd
git rev-parse --show-toplevel
```

- 出力を user に見せ、対象 repo を明示確認させる
- `gh pr create --repo <owner>/<repo>` で対象を固定するのが安全
- default: `--draft --reviewer @user` (pre-pr-create hook が両方無いと block する)
- PR 本文が未準備なら下記の `sadoku` handoff で取得

## Handoff to sadoku (PR 本文未準備時)

Step 4 に入る前に、PR 本文がまだなければ `sadoku` の PR 説明文 mode に handoff:

```
handoff: sadoku
mode: PR 説明文
reason: teishutsu の Step 4 に入る前に本文ドラフトが必要
change intent: [何を解決したか]
files changed:
  - [path]
verification:
  - [command] -> pass / fail
expected return:
  - 5-section PR 本文ドラフト (sadoku references/pr-template.md に準拠)
```

戻ってきた本文を `gh pr create --body "$(cat ...)"` に渡す。

## Handoff Intake

`kouchiku` 計画実行モードの完了報告 or user から呼ばれる時に期待する入力。

```
handoff: teishutsu
reason: 実装完了、PR open まで運んでほしい
files changed:
  - [path]
submodule status:
  - [触れた submodule / 無ければ none]
PR body:
  - [既にあるなら本文、無ければ sadoku に内部 handoff する]
target repo:
  - [owner/repo、submodule なら明示]
reviewer:
  - [@user、未定なら user 判断を仰ぐ]
```

足りない場合は推測で補完せず、停止条件として扱い欠落項目を user に問い合わせる。

## 停止条件

- **cwd 不整合**: cwd が submodule 側なのに親 repo の PR を作ろうとしている (or 逆)
- **未確認の force push**: `--force` / `--force-with-lease` が main / master / develop に対して指定されている (pre-push hook と二重)
- **reviewer 未指定 + 非 draft**: pre-pr-create hook と二重、teishutsu 側でも先に検出
- **リモート衝突未解決**: Step 1 で先行 commit を検出したのに reconcile せず Step 3 に進もうとした
- **submodule pointer 変更ありで submodule 未 push**: Step 2 を skip すると post-commit hook が warning を出す

## Hard Rules

- 各 step は順序を守る (リモート確認 → submodule → 親 → PR)。途中失敗時は次に進まない
- `gh pr create` 直前で必ず `pwd` の出力を user に見せて cwd を明示確認する
- PR / branch / step を独自連番 (PR-1 等) で呼ばない。issue 名 / 機能名 / branch 名で呼ぶ。重複時のみ -v2, -v3 ... のサフィックスを使う
- commit / PR 本文の生成は inline で 1 段落出して user 承認を仰ぐ。承認なしで commit / push しない

## hook との二重構造

| 停止条件 | 本 skill | Phase 3 hook |
|---|---|---|
| non-fast-forward | Step 1 で先制検出 | pre-push が最後の砦 (block) |
| force to protected | Step 3 で警告 | pre-push が block |
| reviewer / draft 未指定 | Step 4 で確認 | pre-pr-create が block |
| submodule 未 push | Step 2 で順序遵守 | post-commit が warning |

**役割分担**: skill は「正常経路で漏れを防ぐ」、hook は「skill を経由しない経路でも止める最後の砦」。teishutsu は hook より厳しい (block しないものを skill が積極的に止める / 確認に上げる)。

## 完了記録

機械検証可能項目は検証ログ (command 出力) をそのまま引用する。

```
worktree:        in-worktree / normal-repo
remote state:    fetched / in sync / had divergence: [...]
                   検証ログ: [git log HEAD..origin/... の最終行 or "(empty)"]
submodule:       none / [path] commit [hash] pushed
                   検証ログ: [git submodule status の出力]
parent commit:   [hash] - [message 1 行]
push result:     pushed to origin/[branch] / hook blocked: [reason]
                   検証ログ: [push command 最終行]
cwd at gh:       [pwd 出力]
                   検証ログ: [pwd 実出力]
PR:              [url] / draft / reviewers: [@user]
```

## subagent

本 skill は判断と git/gh 操作が中心、subagent gate に該当しない (inline 実行)。`sadoku` への handoff は通常 skill 切り替えで行い、subagent 委譲はしない。
