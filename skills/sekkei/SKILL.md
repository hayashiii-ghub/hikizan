---
name: sekkei
description: "Use this skill when the user wants help deciding how to build something, evaluating whether to keep/kill/pivot an approach, or drafting an implementation plan — including phrasings 設計どうする, 方針決めたい, どうやって直す, やり方どっち, やる価値ある, 採用すべきか, kill か keep か. Activate when discussing technical trade-offs before implementation. 承認済みの計画を実行に移す段・原因診断は jikkou。"
license: MIT
when_to_use: "設計判断, 方針決め, design decision, kill or keep, 計画立案"
---

# sekkei (設計)

```
🌲 Using /sekkei for [purpose taken from trigger context].
```

考えて決める skill。コードは触らない。決めた計画の実行と原因診断 (テスト先行の実装含む) は `jikkou`、調べるのは `tansaku`、レビューは `sadoku`、提出は `teishutsu` に渡す。

<!-- hikizan:contract:start -->
## 共通ルール

core skill (init を除く全 skill) 共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `skills/teishutsu/references/commit.md` の粒度契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は skills/teishutsu/references/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は skills/shippitsu/references/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 3 つのモード

| モード | きっかけ | 出すもの |
| --- | --- | --- |
| 軽量検討 | 「どうやって直す」「やり方どっち」/ 対象が 3 ファイル未満 | 推奨案 1 つ |
| 通常検討 | 「設計どうする」「方針決めたい」/ 新機能の着手前 | 計画 |
| 評価 | 「やる価値ある?」「採用すべき?」「やめる?」 | Kill / Keep / Pivot |

前提情報が足りないと感じたら、考え始める前に `tansaku` に渡す (自分で広域探索をやり直さない)。承認された計画の実行と原因診断は `jikkou` に渡す (自分でコードを書かない)。

## 手順 (軽量検討)

1. 推奨案を 1 つ書く: file:line で場所を示し、推奨度 N/10 と根拠 1 行を付ける
2. 雑にやる案 (brute) があれば 1 行で併記する (なければ省略)
3. 採用したときの最大の懸念を 1 つ書く
4. 3 案以上は出さない。明確なら推奨 1 案だけでよい

## 手順 (通常検討)

1. 解決すること / しないこと (out-of-scope) を分けて書く
2. 推奨案を 1 つ決める。迷う近さの代替案があるときだけ併記する (全部で 3 案まで)
3. この設計が前提とする事実 (不変条件 / 制約 / 受容済みリスク) を 3-5 個列挙する。CONTEXT.md があればそこから引き、各々を file:line で確認する。確認できないものには ⚠ を付ける。設計の**決定** (なぜこの案を選んだか) は CONTEXT.md でなく ADR に置き、CONTEXT.md にリンクする
4. 事実で決まらない分岐が残るなら、案を確定する前に一問ずつ user に確認する。対象: 対象範囲が複数に解釈できる / 後から変えるコストが高い設計分岐 / DoD が無い / 影響範囲が広いのに成功条件が曖昧 / ADR に残すべき重い判断。質問には推奨案と理由 (evidence があれば file:line) を 1 つ添える。事実で決まる分岐は自分で file:line を確認して埋める。用語そのもののズレは `tansaku` に戻す
5. 6 ヶ月後に問題になりうるシナリオを 1 つ書く
6. 計画 step に分解する。各 step に担当 skill / 触る file / 検証コマンドを書く
7. 各 step を書く前に `references/minimal-approach.md` の「書く前のラダー」で止める。計画が要求から読める規模の 2 倍以上なら、引き算した最小版を併記する (同ファイル)
8. 出力して「1. 実行する (jikkou へ) / 2. 計画を直す / 3. 中止する」で承認を待つ。承認されるまで実装には入らない。承認されたら `jikkou` に handoff する

出力の全項目と詳細な思考手順: `references/deliberation.md`

## 手順 (評価)

1. Verdict を 1 つ選ぶ: Kill / Keep / Pivot。「保留」は出さない
2. 理由を 1-3 個書く。ユーザの制約 (時間 / 人員 / 顧客への約束 / 競合) に紐づける。技術的な好みだけを理由にしない
3. Pivot なら方向転換先を 1 段落で書く

## やってはいけないこと

- コードを書く / 実装に入る (signature やデータ形の例示 ~5-8 行は可。実装は `jikkou`)
- 3 案以上並べる / 評価で「保留」を出す
- 事実で決まる分岐を user への質問で丸投げする (自分で file:line を確認する)
- 承認前の計画を確定扱いして handoff する

## 報告 (穴埋め)

最初に結論を 1 文。続けて内訳を箇条書きにする。前提の確認は file:line をそのまま添える。

[1 文: 何を決めたか]

- mode: [軽量検討 / 通常検討 / 評価]
- decision: [推奨案 / Verdict (Kill / Keep / Pivot)]
- 前提: [設計が前提とする事実 (file:line)。未確認は ⚠] (通常検討のみ)
- open question: [事実で決まらず user に確認した分岐 / なし]
- scope: [解決すること / out-of-scope]
- next: [jikkou (計画承認後) / sadoku / なし]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `deliberation.md`：通常検討の詳細手順と出力テンプレ
- `minimal-approach.md`：引き算の手順と推奨度 N/10 の付け方
