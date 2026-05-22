---
name: teishutsu
description: "Use this skill when the user wants to submit a pull request or draft a PR body — including the phrasings PR出す, PR提出, PR ready, PR open する, PR文書いて, PR description, submit. Handles PR body drafting and the full submission flow: remote state check, submodule-first ordering, parent commit, cwd-aware gh pr create. Activates after implementation is complete and ready to ship, even when the user just says 提出する or 出す without explicit PR wording."
license: MIT
when_to_use: "PR提出, PR出す, PR ready, PR文書いて, PR description, submission, PR open"
---

# teishutsu (提出)

```
🌲 Using /teishutsu for [purpose taken from trigger context].
```

PR 本文ドラフトから PR open までの提出手順を扱う skill。submission 工程の未確認項目 (リモート状態未確認 / submodule 順序ミス / cwd ミスでの gh コマンド / reviewer 未指定の本番 PR) を検出する。`sadoku` は review / simplify、`teishutsu` は提出に必要な本文と手順を担当する。

## Step 0: worktree 検出

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較する。異なれば worktree 内 — branch 名とともに表示し、完了記録の `worktree` 行に記録する。

## 起動トリガー


| 入力トリガー                                | 状態トリガー                    | 動作                          |
| ------------------------------------- | ------------------------- | --------------------------- |
| `PR文書いて` / `PR description`           | PR open 直前                | Step 4 の PR 本文ドラフトだけを実行して終了 |
| `PR出す` / `PR提出` / `PR ready` / `提出して` | `kouchiku` 計画実行モードの完了報告直後 | 提出フローを実行                    |


状態トリガーは誤起動回避のため、検出後に確認 prompt を 1 行挟む (`実装完了です。PR を出しますか?`)。

## 提出フロー (6 step、順序を守る)

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

- 親 repo で `git add` (submodule pointer 更新含む) → commit message ドラフト → PII / Secrets scan → user 承認 → commit
- この step では push しない

### Step 4: PR 本文ドラフト

PR 本文が未準備なら、`references/pr-template.md` を読み、5 セクション本文をドラフトする。必須 intake は issue / 計画 / change intent のいずれか、diff または変更ファイル一覧、検証コマンドまたは手動確認内容。足りない場合は推測で埋めず、欠けている項目だけ user に確認する。

PII / Secrets scan を本文ドラフトに対して実行し、混入があれば push / PR 作成に進まない。`PR文書いて` / `PR description` で呼ばれた場合は、この step の出力で終了する。

### Step 5: push

```bash
git push
```

- pre-push hook が non-ff / force-to-protected を block する。block 時は Step 1 に戻って原因解消する
- push が失敗したら PR 作成に進まない

### Step 6: PR 作成

**cwd を `gh pr create` 直前で必ず確認** — submodule と親 repo の取り違えを避けるための step:

```bash
pwd
git rev-parse --show-toplevel
```

- 出力を user に見せ、対象 repo を明示確認させる
- `gh pr create --repo <owner>/<repo>` で対象を固定するのが安全
- default: `--draft --reviewer @user` (pre-pr-create hook が両方無いと block する)
- Step 4 で作った本文を `gh pr create --body "$(cat ...)"` に渡す

## Handoff Intake

`kouchiku` 計画実行モードの完了報告 or user から呼ばれる時に期待する入力。

```
handoff: teishutsu
reason: 実装完了、PR open まで運んでほしい
change intent:
  - [何を解決したか]
files changed:
  - [path]
verification:
  - [command] -> pass / fail
scope notes:
  - [やらなかったこと / 実装中に分かったこと]
submodule status:
  - [触れた submodule / 無ければ none]
PR body:
  - [任意: 既にあるなら本文、無ければ Step 4 でドラフトする]
target repo:
  - [任意: owner/repo、submodule なら明示]
reviewer:
  - [任意: @user、未定なら user 判断を仰ぐ]
```

足りない場合は推測で補完せず、停止条件として扱い欠落項目を user に問い合わせる。

## 停止条件

- **PR 本文 intake 不足**: 本文未準備なのに issue / 計画 / change intent のいずれか、diff または変更ファイル一覧、検証コマンドまたは手動確認内容のいずれかが欠けている
- **PII / Secrets 混入**: PR 本文 / commit message / release notes に email, token, 個人名等が混入している
- **cwd 不整合**: cwd が submodule 側なのに親 repo の PR を作ろうとしている (or 逆)
- **未確認の force push**: `--force` / `--force-with-lease` が main / master / develop に対して指定されている (pre-push hook と二重)
- **reviewer 未指定 + 非 draft**: pre-pr-create hook と二重、teishutsu 側でも先に検出
- **リモート衝突未解決**: Step 1 で先行 commit を検出したのに reconcile せず push しようとした
- **submodule pointer 変更ありで submodule 未 push**: Step 2 を skip すると post-commit hook が warning を出す

## Hard Rules

- 各 step は順序を守る (リモート確認 → submodule → 親 commit → PR 本文 → push → PR 作成)。途中失敗時は次に進まない
- `gh pr create` 直前で必ず `pwd` の出力を user に見せて cwd を明示確認する
- PR / branch / step の命名は `kouchiku` Hard Rules に従う
- commit / PR 本文の生成は inline で出して user 承認を仰ぐ。承認なしで commit / push / PR 作成しない

## hook との二重構造


| 停止条件                 | 本 skill      | hook                   |
| -------------------- | ------------ | ---------------------- |
| non-fast-forward     | Step 1 で先制検出 | pre-push が block |
| force to protected   | Step 5 で警告   | pre-push が block       |
| reviewer / draft 未指定 | Step 6 で確認   | pre-pr-create が block  |
| submodule 未 push     | Step 2 で順序遵守 | post-commit が warning  |


**役割分担**: skill は通常フローの手順を扱い、hook は skill を経由しない操作に対する補完的な検査を行う。teishutsu は hook より前の段階で確認項目を検出する。

## 完了記録

機械検証可能項目は検証ログ (command 出力) をそのまま引用する。

```
worktree:        in-worktree / normal-repo
mode:            PR body draft / submit
remote state:    fetched / in sync / had divergence: [...]
                   検証ログ: [git log HEAD..origin/... の最終行 or "(empty)"]
submodule:       none / [path] commit [hash] pushed
                   検証ログ: [git submodule status の出力]
parent commit:   [hash] - [message 1 行]
push result:     pushed to origin/[branch] / hook blocked: [reason]
                   検証ログ: [push command 最終行]
PR body:         drafted / provided / skipped
                   PII scan: clean / found: [...]
cwd at gh:       [pwd 出力]
                   検証ログ: [pwd 実出力]
PR:              [url] / draft / reviewers: [@user]
```

## subagent

本 skill は PR 本文ドラフトと git/gh 操作が中心、subagent gate に該当しない (inline 実行)。

## references/

- `pr-template.md` — PR 本文ドラフトの contract (5 セクション template / 手順 / 文章チェック / PII scan / 粒度ルール)

