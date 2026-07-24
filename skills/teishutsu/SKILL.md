---
name: teishutsu
description: "Use this skill when the user wants a pull request body drafted or committed work pushed and opened as a PR — including PR出す, PR提出, PR ready, PR openする, PR文書いて, PR description. Handles the external submission boundary; it does not implement or commit unfinished work."
license: MIT
when_to_use: "PR提出, PR出す, PR ready, PR文書いて, PR description, submission, PR open"
---

# teishutsu (提出)

PR本文を作り、明確な提出先へ通常pushしてPRを作る。userの明示的な提出依頼は、一意に確定できるrepo・branch・完成scopeへの通常commit・push・PR作成を許可する。

<!-- hikizan:contract:start -->
## 共通ルール

全skill共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- skillを固定順に通さない。各skillは依頼された成果と、そのために必要な可逆の局所作業を同じtask内で完了する
- userに確認するのは、結果やscopeを大きく変える未決事項、曖昧な外部操作、元に戻せない操作だけ。明確で可逆な作業は止めない
- 検証はriskに比例させ、実行したcommandと判定に必要な結果を残す。未検証の状態をpass・完了と書かない
- force push、履歴破壊、削除などの不可逆操作はuserの明示確認なしに実行しない
- PR本文・commit message・公開文にtoken、email、チーム外の実名を含めない。外へ出す直前に対象をscanする
<!-- hikizan:contract:end -->

## モード

- 本文ドラフト：「PR文書いて」なら本文だけ作る
- 提出：「PR出して」ならtarget確認からpush・PR作成まで行う

## 手順

1. `pwd`、repo root、current branchを確認する。push remoteはbranch設定、なければ唯一のremoteから決め、fetch URLとpush URLを読む
2. PR repoはuser指定、なければpush URLから一意に対応するGitHub repoとする。PR remoteはそのrepoに対応するlocal remote、baseはuser指定、`branch.<branch>.gh-merge-base`、PR remoteのdefault branchの順で決める。feature branchのupstreamをbaseにしない。forkではpush remoteとPR remoteを分け、headを`<push-owner>:<branch>`にする
3. `repo / base <- head / push remote`を表示する。fork、複数候補、fetch URLとpush URLの相違、target変更がある場合だけnetwork操作前にuserへ確認する。選んだpush remoteと、異なる場合はPR remoteだけfetchし、remote先行や履歴差分を確認する。解消方針が必要なら勝手にrebase・merge・forceしない
4. 未commit差分がある場合は、完成・検証済みで1つのreview可能な目的に閉じていると確認できるときだけ`jikkou`のcommit契約に従ってcommitする。未完成、検証不明、混在scopeなら停止する。その後worktreeがcleanでbaseとのrangeが空でないことを確認する。`.gitmodules`がある場合だけsubmoduleの未commit・未pushも確認する
5. `references/pr-template.md`で変更規模に合う本文とtitleを作る。提出rangeの追加行、本文、commit message、release noteへ秘密情報scanを行う
6. remoteは空・先頭`-`を拒否して`git remote`の1行と完全一致させ、branchとbaseは`git check-ref-format --branch`で検証する。初回は明示refspecでupstreamを設定し、それ以降も明示remote・refspecで通常pushする
7. 本文はpermissionを絞ったtemporary fileへ置き、作成直後にsuccess・failure・interruptの全経路で動くcleanupを登録する。`gh pr create --repo ... --base ... --head ... --title ... --body-file ...`へ検証済み値をquoteして渡し、`--draft`か`--reviewer`を必ず付ける。ready指定でreviewerを一意に決められない場合は確認し、それ以外はdraftを既定にする
8. PR URL、base/head、draft/reviewer状態を確認する。pushまたはPR作成に失敗したら完了扱いせず、cleanup後に停止する

## 停止する場合

- targetを一意に決められない
- ready PRのreviewerを一意に決められない
- remoteが先行し、解消方法の判断が必要
- 未完成・検証不明・複数目的の未commit scopeが残る
- force push、履歴改変、または確認済みtargetと異なるrepoへの変更が必要
- secretやPIIが公開対象に残る

## やってはいけないこと

- 全remoteのfetchや曖昧なupstreamへ依存する
- userの明示依頼を、別target・force・履歴改変への承認に広げる
- push失敗や検証不明のままPR作成へ進む
- command文字列を`eval`する、返却commandをそのまま実行する

## 報告

提出できたかを最初に書き、PR URL、base/head、push結果、検証・未解決事項だけを続ける。

## references/

- `pr-template.md`：PR本文、title、公開前scanを作るときに読む
- `naming.md`：repo固有規約がない場合のbranch・commit・PR命名
