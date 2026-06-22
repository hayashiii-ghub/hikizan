---
name: kouchiku
description: "Use this skill when the user wants help deciding how to build something, evaluating whether to keep/kill/pivot an approach, drafting an implementation plan, or executing an approved plan — including phrasings 設計どうする, 方針決めたい, どうやって直す, やり方どっち, やる価値ある, 採用すべきか, kill か keep か, 計画実行, 進めて, 着手. Activate when discussing technical trade-offs, or when the user just got approval and wants implementation — even without explicit 'design' or 'plan' wording."
license: MIT
when_to_use: "設計判断, 方針決め, design decision, kill or keep, 計画実行"
---

# kouchiku (構築)

```
🌲 Using /kouchiku for [purpose taken from trigger context].
```

考えて決めて実行する skill。調べるのは `tansaku`、テスト先行の実装は `shiken`、レビューは `sadoku`、提出は `teishutsu` に渡す。

<!-- hikizan:contract:start -->
## 共通ルール

全 skill 共通。`scripts/check-consistency.sh` が 6 skill で同一であることを検査する。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は docs/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / 渡すこと: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は docs/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 5 つのモード

| モード | きっかけ | 出すもの |
| --- | --- | --- |
| 軽量検討 | 「どうやって直す」「やり方どっち」/ 対象が 3 ファイル未満 | 推奨案 1 つ |
| 通常検討 | 「設計どうする」「方針決めたい」/ 新機能の着手前 | 計画 |
| 評価 | 「やる価値ある?」「採用すべき?」「やめる?」 | Kill / Keep / Pivot |
| 計画実行 | 「進めて」「計画実行」「着手」(計画の承認後) | 動くコード + 検証ログ |
| 診断 | 「エラー」「動かない」/ 原因の分からない不具合・test failure | root cause 1 文 + fix |

前提情報が足りないと感じたら、考え始める前に `tansaku` に渡す (自分で広域探索をやり直さない)。

## 手順 (軽量検討)

1. 推奨案を 1 つ書く: file:line で場所を示し、推奨度 N/10 と根拠 1 行を付ける
2. 雑にやる案 (brute) があれば 1 行で併記する (なければ省略)
3. 採用したときの最大の懸念を 1 つ書く
4. 3 案以上は出さない。明確なら推奨 1 案だけでよい

## 手順 (通常検討)

1. 解決すること / しないこと (out-of-scope) を分けて書く
2. 推奨案を 1 つ決める。迷う近さの代替案があるときだけ併記する (全部で 3 案まで)
3. この設計が前提とする事実を 3-5 個列挙し、各々を file:line で確認する。確認できないものには ⚠ を付ける
4. 6 ヶ月後に問題になりうるシナリオを 1 つ書く
5. 計画 step に分解する。各 step に担当 skill / 触る file / 検証コマンドを書く
6. 各 step を書く前に `references/minimal-approach.md` の「書く前のラダー」で止める。計画が要求から読める規模の 2 倍以上なら、引き算した最小版を併記する (同ファイル)
7. 出力して「1. 実装する / 2. 計画を直す / 3. 中止する」で承認を待つ。承認されるまで実装コードを書かない

出力の全項目と詳細な思考手順: `references/design.md`

## 手順 (評価)

1. Verdict を 1 つ選ぶ: Kill / Keep / Pivot。「保留」は出さない
2. 理由を 1-3 個書く。ユーザの制約 (時間 / 人員 / 顧客への約束 / 競合) に紐づける。技術的な好みだけを理由にしない
3. Pivot なら方向転換先を 1 段落で書く

## 手順 (計画実行)

1. 承認済みの計画を再読する。不明点があれば実装前に聞く
2. step を 1 つずつ自分で実装する (subagent に投げない)
3. 純ロジック / ビジネスルール / API / バグ修正の step は、自分で書かず `shiken` に 1 slice ずつ渡す (slice の形式は `references/execution.md`)
4. 各 step の後に検証コマンドを実行し、出力の最終行を控える。失敗したら次の step に進まず診断に入る
5. UI / レイアウト / 視覚に触れる step は、検証コマンドに加えて視覚検証も通す (web project かつ `sitesnap` があるとき。shot で撮って --json の file を Read で読み戻して目視し、check --json の合否を step 通過判定にする)。撮れない環境では「視覚未確認」と報告に明記してスキップする
6. 計画に無いファイルに 5 つ以上触れそうになったら、止めてユーザに scope を確認する
7. scope 外の発見は実装せず「実装中に分かったこと」にメモする
8. 全 step 完了後、下の「報告」を埋めて `sadoku` に渡す

詳細: `references/execution.md`

## 手順 (診断)

1. 実装の変更を止める
2. 症状をそのまま書き出す: error message / stack trace / 再現手順 / 期待値と実際の値
3. 原因の仮説を 1 文で書く: 「root cause は [X]。根拠は [evidence]」
4. `references/diagnosis-techniques.md` から確認手段を 1 つ選んで仮説を検証する
5. 当たっていたら直す。外れていたら 3 に戻る
6. 3 回外れたら、試した仮説 / 現状の見立て / 残る不明点を書いてユーザに判断を求める
7. 直した後、同じ入力での before / after の出力をそのまま貼る。regression guard が要るなら `shiken` に渡す

## やってはいけないこと

- 計画の承認前に実装コードを書く (signature やデータ形の例示 ~5-8 行は可)
- 3 案以上並べる / 評価で「保留」を出す
- 原因不明のまま当てずっぽうの修正を重ねる
- scope 外の発見をついでに実装する
- 検証コマンドが失敗したまま次の step に進む

## 報告 (穴埋め)

```
mode: [軽量検討 / 通常検討 / 評価 / 計画実行 / 診断]
done: [N / M step]                     (計画実行のみ)
検証: [コマンド] → [出力の最終行をそのまま]
visual: [shot のパス / 視覚未確認 (理由) / 該当なし]   (UI step のみ)
root cause: [1 文 + before/after]      (診断のみ)
scope: [計画どおり / 外れたもの → 別 issue へ]
次: [shiken / sadoku / teishutsu / なし]
```

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `design.md` — 通常検討の詳細手順と出力テンプレ
- `execution.md` — 計画実行の詳細 (TDD 分岐 / slice の渡し方 / 診断の入り方)
- `diagnosis-techniques.md` — 診断の確認手段
- `minimal-approach.md` — 引き算の手順と推奨度 N/10 の付け方
