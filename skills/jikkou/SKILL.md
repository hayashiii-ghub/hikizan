---
name: jikkou
description: "Use this skill when the user wants to execute an already-approved plan or diagnose a failure — including phrasings 進めて, 計画実行, 着手, 実装開始, 実装して, エラー, 動かない, 落ちる, クラッシュ, 前は動いてた, 原因が分からない. Activate when the user just approved a plan and wants it built, or reports a bug/test failure whose root cause is unknown. 設計判断そのものは sekkei に戻す。"
license: MIT
when_to_use: "計画実行, 実装, エラー診断, root cause, バグ修正"
---

# jikkou (実行)

```
🌲 Using /jikkou for [purpose taken from trigger context].
```

承認済みの計画を実行し、原因不明の不具合を診断する skill。設計・計画・評価は `sekkei`、テスト先行の実装は `shiken`、レビューは `sadoku`、提出は `teishutsu`、調べ直しは `tansaku` に渡す。方針の再決定が要るときは `sekkei` に差し戻す。

<!-- hikizan:contract:start -->
## 共通ルール

全 skill 共通。`scripts/check-consistency.sh` が 7 skill で同一であることを検査する。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は docs/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は docs/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 2 つのモード

| モード | きっかけ | 出すもの |
| --- | --- | --- |
| 計画実行 | 「進めて」「計画実行」「着手」(計画の承認後) | 動くコード + 検証ログ |
| 診断 | 「エラー」「動かない」/ 原因の分からない不具合・test failure | root cause 1 文 + fix |

計画がまだ承認されていない、または方針を決め直す必要があるときは `sekkei` に渡す (自分で設計判断をしない)。

## 手順 (計画実行)

1. 承認済みの計画を再読する。不明点があれば実装前に聞く。計画が無い / 未承認なら `sekkei` に戻す
2. step を 1 つずつ自分で実装する (subagent に投げない)
3. 純ロジック / ビジネスルール / API / バグ修正の step は、自分で書かず `shiken` に 1 slice ずつ渡す (slice の形式は `references/plan-execution.md`)
4. 各 step の後に検証コマンドを実行し、出力の最終行を控える。失敗したら次の step に進まず診断に入る
5. UI / レイアウト / 視覚に触れる step は、検証コマンドに加えて視覚検証も通す (web project かつ `sitesnap` があるとき。shot で撮って --json の file を Read で読み戻して目視し、check --json の合否を step 通過判定にする)。撮れない環境では「視覚未確認」と報告に明記してスキップする
6. 計画に無いファイルに 5 つ以上触れそうになったら、または方針の再決定が要ると分かったら、止めて `sekkei` に差し戻す
7. scope 外の発見は実装せず「実装中に分かったこと」にメモする
8. 全 step 完了後、下の「報告」を埋めて `sadoku` に渡す

詳細: `references/plan-execution.md`

## 手順 (診断)

1. 実装の変更を止める
2. 症状をそのまま書き出す: error message / stack trace / 再現手順 / 期待値と実際の値
3. 原因の仮説を 1 文で書く: 「root cause は [X]。根拠は [evidence]」
4. `references/diagnosis-techniques.md` から確認手段を 1 つ選んで仮説を検証する
5. 当たっていたら直す。外れていたら 3 に戻る
6. 3 回外れたら、試した仮説 / 現状の見立て / 残る不明点を書いてユーザに判断を求める。方針ごと考え直す重い分岐なら `sekkei` に戻す
7. 直した後、同じ入力での before / after の出力をそのまま貼る。regression guard が要るなら `shiken` に渡す

## やってはいけないこと

- 未承認 / 不在の計画をそのまま実装に移す (設計判断は `sekkei` に戻す)
- 原因不明のまま当てずっぽうの修正を重ねる
- scope 外の発見をついでに実装する
- 検証コマンドが失敗したまま次の step に進む

## 報告 (穴埋め)

最初に結論を 1 文。続けて内訳を箇条書きにする。検証はコマンド出力の最終行をそのまま貼る。

[1 文: どこまで進めた / 原因は何か]

- mode: [計画実行 / 診断]
- done: [N / M step] (計画実行のみ)
- verification: [コマンド] → [出力の最終行をそのまま]
- visual: [shot のパス / 視覚未確認 (理由) / 該当なし] (UI step のみ)
- root cause: [1 文 + before/after] (診断のみ)
- scope: [計画どおり / 外れたもの → sekkei へ差し戻し or 別 issue へ]
- next: [shiken / sadoku / teishutsu / sekkei / なし]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `plan-execution.md`：計画実行の詳細 (TDD 分岐 / slice の渡し方 / 診断の入り方)
- `diagnosis-techniques.md`：診断の確認手段
