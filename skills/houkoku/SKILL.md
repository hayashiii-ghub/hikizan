---
name: houkoku
description: "Use this skill when the user wants a completed task, review, PR, or release reported clearly — including the phrasings 何をした, 結果を教えて, 完了報告, 作業報告, Slackで共有, リリース報告, handoff, 報告して. Activate as the sixth and final hikizan step after implementation, review, or submission. In ordinary chat, communicate the outcome and reasoning as natural prose rather than a fixed status template; preserve verification evidence, uncertainty, remaining work, and next actions without inventing facts."
license: MIT
when_to_use: "報告, 完了報告, 作業結果, 何をした, Slack共有, リリース報告, handoff"
---

# houkoku (報告)

```
🌲 Using /houkoku for [purpose taken from trigger context].
```

hikizanの6番目にあたる最終工程。実装・レビュー・提出で得た事実を、利用者が次の判断に使える報告へ変換する。報告そのもののために実装や提出をやり直さず、観測できない内容は推測しない。日本語は`references/writing-style.md`に従い、長いリリース報告やincident reportだけ`references/cognitive-rhythm.md`も使う。

<!-- hikizan:contract:start -->
## 共通ルール

全skill共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `jikkou` の commit 契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は `teishutsu` の naming reference)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は `houkoku` の writing-style 規範に従う
<!-- hikizan:contract:end -->

## 3つのモード

| モード | きっかけ |
| --- | --- |
| 会話報告 | 通常のchatやSlackで、判断と結果を自然に共有する |
| リリース報告 | version間の変更、移行時の注意、利用者への影響をまとめる |
| handoff | 次の担当・skillへ、判断に必要な証拠と残件を渡す |

## 入力

- 利用者が知りたい対象と期間
- 実際に変えた範囲
- 実行した検証と、その出力
- 未完了・未確認・既知のリスク
- PR、release、fileなどの参照先

不足している項目を推測で埋めない。必要なら`未確認`と明記する。

## 手順

1. 誰に、どの作業・version・期間を報告するかを決める
2. diff、検証出力、PRやreleaseの状態から事実を集める
3. 会話報告では、結論または現在の判断が早く伝わる自然な文章にする。固定の順序やfield名は使わない
4. `references/writing-style.md`を当てる。長いリリース報告やincident reportでは`references/cognitive-rhythm.md`も当てる
5. 事実・推測・未確認を分ける。`passした`、`公開した`、`マージした`などの状態表現を証拠と照合し、仮説なら言い切らない
6. 続く作業がある場合だけ、最後に1行のhandoffを置く

## 出力

`changed`、`verified`、`remaining`、`next`、`links`は含める情報の候補であり、見出しや出力順のtemplateではない。必要な情報だけを、利用者の次の判断へつながる形で出す。

- 通常のchatやSlackでは、周囲の会話に合う自然な散文を既定にする
- 判断理由が重要なら、原因の見立て、変更した理由、期待する効果のつながりを説明する
- 複数の変更や比較だけ、読みやすくなる範囲で箇条書きにする
- releaseやhandoff、一覧性を求められた報告では見出しと箇条書きを使う
- 検証できていない効果は、仮説・見込み・未確認として書く

長さは作業量ではなく、利用者の次の判断に必要な情報量で決める。

## やってはいけないこと

- 実行していない検証を`pass`と書く
- draft、未push、未公開の状態を完了扱いする
- 実装過程の細部を、利用者の判断に不要なのに列挙する
- 通常の会話で`changed:`のような固定fieldを機械的に並べる
- 例文の言い回しや段落順をtemplateとして再現する
- 残件や未確認事項を隠す
- 報告のためにコードレビューを始める (`sadoku`へ)
- 報告のためにPRを作る (`teishutsu`へ)

## references/

- `writing-style.md`：報告を含む日本語文章規範の正本
- `cognitive-rhythm.md`：長いリリース報告・incident report向けの追加規範
