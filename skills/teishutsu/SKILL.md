---
name: teishutsu
description: "Use this skill when the user wants to submit a pull request or draft a PR body — including the phrasings PR出す, PR提出, PR ready, PR open する, PR文書いて, PR description, submit. Handles PR body drafting and the full submission flow: remote state check, committed-scope check, submodule readiness, normal push, and cwd-aware gh pr create. Activates after implementation is complete and ready to ship, even when the user just says 提出する or 出す without explicit PR wording."
license: MIT
when_to_use: "PR提出, PR出す, PR ready, PR文書いて, PR description, submission, PR open"
---

# teishutsu (提出)

```
🌲 Using /teishutsu for [purpose taken from trigger context].
```

PR 本文を書いて PR を出す skill。レビューは `sadoku`。ここが hikizan の**出口**: どの進め方で実装したかに関わらず、PR はこの形式に収束させる。

<!-- hikizan:contract:start -->
## 共通ルール

core skill (init を除く全 skill) 共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `skills/jikkou/references/commit.md` の粒度契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は skills/teishutsu/references/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は skills/shippitsu/references/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 2 つのモード

| モード | きっかけ | 動作 |
| --- | --- | --- |
| 本文ドラフト | 「PR文書いて」「PR description」 | 手順 4 (本文ドラフト) だけ実行して終了 |
| 提出 | 「PR出す」「PR提出」「PR ready」「提出して」 | 手順 1〜6 を順に実行 |

提出モードの明示起動は、手順 1〜3 で確定する親 repo / branch / commit 済み scope に対する通常 push・PR 作成の一括承認とみなす。実装完了の直後など状態から起動するときは手順 1〜3 の read-only 確認を行い、対象を示してから 1 行確認する (`[repo] / [branch] / [scope] を push して PR を出しますか?`)。未 commit 差分、submodule 側の変更、remote 先行の解消、repo / branch / scope の変更、履歴改変・破壊的操作にはこの承認を広げない。対象が変わったら承認を取り直す。

## 手順 (順番を変えない・飛ばさない)

1. **対象 / リモート確認**：`pwd` / `git rev-parse --show-toplevel` / `git branch --show-current` で親 repo と branch を確定し、`git fetch --all` → `git log HEAD..origin/<branch> --oneline` を実行する。リモートに先行 commit があれば、別の実装が存在しうることを警告し、pull --rebase / 別 branch / 中止のどれにするかユーザに聞く。解決するまで次に進まない
2. **submodule 準備確認**：`git submodule status --recursive` で対象を列挙し、各 submodule の `git status --short --branch` と upstream がある場合の `git log @{u}..HEAD --oneline` を確認する。未 commit / 未 push の submodule があれば commit / push せず、対象 submodule と状態を示して `jikkou` または元の実装 skill に差し戻す
3. **commit 済み scope 確認**：親 repo の `git status --short` が空であることを確認し、base から HEAD までの変更 file を scope として記録する。未 commit 差分があれば commit せず、差分を示して `jikkou` または元の実装 skill に差し戻す。状態起動ならここで repo / branch / scope を示して提出承認を得る
4. **本文ドラフト**：`references/pr-template.md` を読み、6 セクション (課題 / DoD / 実装の流れとレビュー順 / 実装中に分かったこと / 検証 / Workflow) を埋める。必要な材料は (issue・計画・変更意図のどれか) + (diff か変更ファイル一覧) + (検証コマンドか手動確認)。足りなければ推測で埋めず、欠けている項目だけユーザに聞く。本文にも秘密情報の grep をかける。「PR文書いて」で呼ばれたときはここで終了
5. **push**：`git push`。hook に止められたら理由を読み、手順 1 に戻る。push が失敗したまま PR 作成に進まない
6. **PR 作成**：`gh pr create` の直前に `pwd` と `git rev-parse --show-toplevel` を実行してユーザに見せ、対象 repo を確認する (submodule と親 repo の取り違え防止)。`--repo <owner>/<repo>` で対象を固定し、`--draft` か `--reviewer` を必ず付け (両方無いと hook が止める)、手順 4 の本文を `--body` で渡す

## やってはいけないこと

- 提出モードの明示起動または状態起動時のユーザ承認なしに、親 repo の push / PR 作成を始める
- `teishutsu` 内で commit を作る
- 親 repo への一括承認を、未 commit 差分、submodule 側の変更、別 repo / branch / scope、履歴改変・破壊的操作に広げる
- 材料が足りない本文を推測で埋める
- リモートの先行 commit を解決しないまま push する
- 未 commit / 未 push の submodule を残したまま親を push する
- cwd を確認せずに `gh pr create` を実行する
- 検証していないのに「検証済み」と書く

## 報告 (穴埋め)

最初に結論を 1 文。続けて各ステップの結果を残す。コマンド出力はそのまま貼る。

[1 文: 何を提出した / どこまで進めたか]

- mode: [本文ドラフトのみ / 提出]
- remote: [git log HEAD..origin/... の最終行 / "(empty)"]
- submodule: [なし / path + 状態 (git submodule status の出力)]
- scope: [base..HEAD の変更 file]
- push: [push 出力の最終行 / hook に止められた理由]
- cwd at gh: [pwd の実出力]
- PR: [URL] / [draft か reviewer]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `pr-template.md`：PR 本文の形式 (6 セクション template / 文章チェック / PII scan / 粒度ルール)
- `naming.md`：識別子の命名規範 (branch / commit subject / PR タイトル / issue タイトル)
