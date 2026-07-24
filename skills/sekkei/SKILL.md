---
name: sekkei
description: "Use this skill when the user explicitly wants a design decision, trade-off evaluation, kill/keep/pivot judgment, or implementation plan — including 設計どうする, 方針決めたい, どうやって直す, やり方どっち, 採用すべきか, 計画にして. Do not require it before clear, reversible implementation work."
license: MIT
when_to_use: "設計判断, 方針決め, design decision, kill or keep, 計画立案"
---

# 設計（sekkei）

実装前に価値のある判断だけを明確にする。小さな変更へ設計工程を追加しない。

<!-- hikizan:contract:start -->
## 共通ルール

全skill共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 各skillを起動したら、作業前に1行だけ `🌲 <skill名>（日本語名）：<今回の目的>` と伝える。同じskill内の局所作業では繰り返さない
- skillを固定順に通さない。各skillは依頼された成果と、そのために必要な可逆の局所作業を同じtask内で完了する
- userに確認するのは、結果やscopeを大きく変える未決事項、曖昧な外部操作、元に戻せない操作だけ。明確で可逆な作業は止めない
- 検証はriskに比例させ、実行したcommandと判定に必要な結果を残す。未検証の状態をpass・完了と書かない
- force push、履歴破壊、削除などの不可逆操作はuserの明示確認なしに実行しない
- PR本文・commit message・公開文にtoken、email、チーム外の実名を含めない。外へ出す直前に対象をscanする
<!-- hikizan:contract:end -->

## 使い分け

- 方針決定：推奨案と重要なtrade-offを決める
- 評価：Kill / Keep / Pivotのどれかを理由付きで選ぶ
- 計画：実装可能なstepと検証方法へ落とす

## 手順

1. 解決することとscope外を短く分ける
2. code・test・docsから判断に必要な事実だけ確認する。広い未知領域の調査自体が成果なら`tansaku`を使えるが、局所確認は自分で行う
3. ゼロベース・メタ評価を求められた場合、または新しい仕組み・抽象化・工程を足す場合は、既存案をいったん外し、目的と必須制約だけから最小構成を考える。そもそもの必要性と、責務を置く層も確認する
4. 推奨案を1つ決める。代替案は結論が拮抗するときだけ1つ添える
5. 要求、既存構造、rollback容易性、security・data・public interfaceへの影響でriskを評価する
6. 結果やscopeを大きく変える未決事項だけuserに確認する。明確な選択や可逆な詳細は自分で決める
7. 計画を求められたら、observableな変更・主なfile・検証をstepにする。`references/minimal-approach.md`で要求外の作業を落とす
8. 同じ依頼に実装も含まれる場合は、未決事項がなければ承認のためだけに止まらず実装へ続ける

## 報告

推奨する判断を最初に書く。必要な場合だけtrade-off、未決事項、最小planを続ける。評価ではKill / Keep / Pivotを曖昧にしない。

## 禁止事項

- file数や行数だけで設計工程を重くする
- 明確な依頼へ選択肢menuや形式的な再承認を追加する
- 要求外の将来拡張をplanへ混ぜる

## 関連資料

- `minimal-approach.md`：planや設計案から要求外の複雑さを落とすときに読む
