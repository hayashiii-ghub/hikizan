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

全skill共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `jikkou` の commit 契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は `teishutsu` の naming reference)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
<!-- hikizan:contract:end -->

## 2 つのモード

| モード | きっかけ | 動作 |
| --- | --- | --- |
| 本文ドラフト | 「PR文書いて」「PR description」 | 手順 4 (本文ドラフト) だけ実行して終了 |
| 提出 | 「PR出す」「PR提出」「PR ready」「提出して」 | 手順 1〜6 を順に実行 |

提出モードの明示起動は、手順1でnetwork接続前にlocal configだけから一意に確定・表示できた `PUSH_REMOTE / PUSH_URL / PUSH_REF / PR_REMOTE / PR_URL / PR_REPO / PR_BASE / PR_BASE_REF / PR_HEAD` と、手順3のcommit済みscopeに対する通常push・PR作成の一括承認とみなす。候補が複数、push URLがfetch URLと異なる、fork構成、または値を一意に確定できない場合は、明示起動でもnetwork前にuser確認を取る。状態から起動するときも同じtupleを表示して1行確認する。未commit差分、submodule側の変更、remote先行の解消、repo / branch / scope / URL / ref / PR targetの変更、履歴改変・破壊的操作には承認を広げない。対象が変わったら承認を取り直す。

## 手順 (順番を変えない・飛ばさない)

1. **local target確定 → 承認 → fetch**：`pwd` / `git rev-parse --show-toplevel` / `git branch --show-current`で親repoとbranchを確定する。network接続前に、branch設定のremote、無ければ唯一のremoteを`PUSH_REMOTE`とし、local configからfetch URL / push URLを読む。`PR_REPO`はuser指定、無ければpush URLから一意に対応づけられるGitHub `owner/repo`とする。`PR_REMOTE`は`PR_REPO`へ対応する既存local remote、`PR_URL`はそのfetch URL。`PR_BASE`はuser指定、`branch.<branch>.gh-merge-base`、`PR_REMOTE`のlocal default branchの順で決め、`PR_BASE_REF=$PR_REMOTE/$PR_BASE`を固定する。feature branchのupstreamをPR baseに使わない。同一repoなら`PR_REMOTE=$PUSH_REMOTE`と`PR_HEAD=<branch>`、forkならuserに`PR_REMOTE / PR_REPO`を確認して`PR_HEAD=<push-owner>:<branch>`とする。対応するlocal remoteが無ければ停止する。remoteは空文字と先頭`-`を拒否したうえで`git remote`の1行と完全一致させ、branch / baseは先頭`-`を拒否して`git check-ref-format --branch`、組み立てたpush ref / `PR_BASE_REF`は`git check-ref-format`で検証する。`PR_REPO`は`^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`に限定し、外れる値はshellへ渡さず停止する。tupleを表示して承認規則を満たしてから`PUSH_REMOTE`と、異なる場合は`PR_REMOTE`をfetchする。承認後に既存PR metadataを取得してtupleと違った場合は再承認する。同名push branchが存在するときだけ先行commitを確認し、無ければ初回pushとして正常扱いする。remote先行があれば解消方法をuserに聞き、解決まで次へ進まない
2. **submodule 準備確認**：`git submodule status --recursive` で対象を列挙し、各 submodule の `git status --short --branch` と upstream がある場合の `git log @{u}..HEAD --oneline` を確認する。未 commit / 未 push の submodule があれば commit / push せず、対象 submodule と状態を示して `jikkou` または元の実装 skill に差し戻す
3. **commit 済み scope 確認**：親repoの `git status --short` が空であることを確認し、remote-qualifiedな`PR_BASE_REF`とのmerge-baseからHEADまでを `SUBMIT_RANGE=<merge-base>...HEAD` として固定する。rangeが空、または`PR_BASE_REF`がcurrent branchと同じcommitなら停止する。そのrangeの変更fileをscopeとして記録する。未commit差分があればcommitせず、差分を示して`jikkou`または元の実装skillに差し戻す。状態起動ならscopeを加えた承認tupleを再表示し、push / PR作成への1行承認を得る。承認までは手順4以降へ進まない
4. **本文ドラフト**：`references/pr-template.md` を読み、6セクション (課題 / DoD / 実装の流れとレビュー順 / 実装中に分かったこと / 検証 / Workflow) を埋める。必要な材料は (issue・計画・変更意図のどれか) + (`SUBMIT_RANGE`のdiffか変更ファイル一覧) + (検証コマンドか手動確認)。足りなければ推測で埋めず、欠けている項目だけuserに聞く。PR本文、`SUBMIT_RANGE`のcommit message、release notes、本文へ転載する検証ログに共通のPII / Secrets scanをかける。「PR文書いて」で呼ばれたときはここで終了
5. **push**：同名remote branchが無い初回は、現在のupstreamがPR baseを指していても `git push --set-upstream "$PUSH_REMOTE" "HEAD:refs/heads/$BRANCH"` を使う。同名remote branchが存在する場合は `git push "$PUSH_REMOTE" "HEAD:refs/heads/$BRANCH"` を使う。allowlist済み変数をquoteした固定shell sourceかstructured argv APIで渡し、placeholderをcommand文字列へ展開・`eval`しない。hookに止められたら理由を読み手順1に戻る。push失敗のままPR作成へ進まない
6. **PR 作成**：直前に`pwd`と`git rev-parse --show-toplevel`を実行し、承認済み`PR_REPO / PR_BASE / PR_HEAD`を再表示する。mode 700の一時directoryを作った直後に、冪等な`cleanup`を`EXIT`へ登録する。`HUP / INT / TERM`は各trapを解除し、cleanup後にそれぞれ129 / 130 / 143で明示終了するhandlerへ分け、interrupt後は提出を続行しない。本文とtitleをmode 600のfileへ保存する。固定shell sourceでは`IFS= read -r title < "$title_file"`のように読み、`gh pr create --repo "$PR_REPO" --base "$PR_BASE" --head "$PR_HEAD" --title "$title" --body-file "$body_file"`と全変数をquoteする。structured argv APIでも同じ承認済み値だけを渡す。`--draft`か`--reviewer`を必ず付け、成功・失敗・interruptの全経路で一時directoryを削除する

## やってはいけないこと

- 提出モードの明示起動または状態起動時のユーザ承認なしに、親 repo の push / PR 作成を始める
- `teishutsu` 内で commit を作る
- 親repoへの一括承認を、未commit差分、submodule側の変更、別repo / branch / scope / remote URL / ref、履歴改変・破壊的操作に広げる
- 材料が足りない本文を推測で埋める
- リモートの先行 commit を解決しないまま push する
- `PUSH_REMOTE / PUSH_URL / PUSH_REF / PR_REMOTE / PR_URL / PR_REPO / PR_BASE / PR_BASE_REF / PR_HEAD`をnetwork前に表示せずfetch / push / PR作成する
- 未 commit / 未 push の submodule を残したまま親を push する
- cwd を確認せずに `gh pr create` を実行する
- 検証していないのに「検証済み」と書く

## 報告 (穴埋め)

最初に結論を 1 文。続けて各ステップの結果を残す。コマンド出力はそのまま貼る。

[1 文: 何を提出した / どこまで進めたか]

- mode: [本文ドラフトのみ / 提出]
- remote: [PUSH_REMOTE / fetch URL / PUSH_URL / PUSH_REF / remote branch: existingまたはnew / 先行logの最終行]
- PR target: [PR_REMOTE / PR_URL / PR_REPO / PR_BASE / PR_BASE_REF / PR_HEAD]
- submodule: [なし / path + 状態 (git submodule status の出力)]
- scope: [SUBMIT_RANGE + 変更 file]
- push: [明示remote + refspec / push出力の最終行 / hookに止められた理由]
- cwd at gh: [pwd の実出力]
- PR: [URL] / [draft か reviewer]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `pr-template.md`：PR 本文の形式 (6 セクション template / 文章チェック / PII scan / 粒度ルール)
- `naming.md`：識別子の命名規範 (branch / commit subject / PR タイトル / issue タイトル)
