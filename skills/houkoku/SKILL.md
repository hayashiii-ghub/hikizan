---
name: houkoku
description: "Use this skill when the user explicitly wants a report, Slack message, release note, or handoff drafted from completed work — including 何をした, 結果を教えて, 完了報告, 作業報告, Slackで共有, リリース報告, handoff. Ordinary task completion should be reported naturally without activating a separate final workflow step."
license: MIT
when_to_use: "報告, 完了報告, 作業結果, 何をした, Slack共有, リリース報告, handoff"
---

# 報告（houkoku）

既にある事実を、読み手が次の判断に使える文章へ変える。報告のために実装・review・提出をやり直さない。

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

## 手順

1. 読み手、対象、期間を確認する。一意なら質問しない
2. diff、検証出力、PR・release状態から事実を集める
3. 結果または現在の判断を先に書き、その理由、検証、残件のうち必要なものだけ続ける
4. chatやSlackは自然な短い散文、releaseや一覧は見出しと箇条書きを使う。`references/writing-style.md`を適用する
5. 事実、見込み、未確認を区別する。次の担当へ本当に移す場合だけhandoffを明記する

## 禁止事項

- draft、未push、未公開を完了扱いする
- 実行していない検証や効果を事実として書く
- 固定fieldや実装過程を、読み手に不要なのに並べる
- 報告を別の必須工程として通常taskへ追加する

## 関連資料

- `writing-style.md`：自然で簡潔な日本語へ整えるときに読む
