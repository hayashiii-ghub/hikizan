# 計画実行モードの手順

承認済み計画を実行する手順の詳細。前提: 通常検討の出力に推奨案 / Key decisions / Plan steps が含まれている。検証はコマンド出力を引用し、scope 外は記録のみ、計画に無い 5+ ファイル touch で停止、元に戻せない操作はユーザ確認。ここは省略しない。

## 手順

1. 計画を再読し、不明点があれば確認を投げる
2. step ごとに inline で実装 (subagent には委譲しない)
3. 各 step 完了後に検証 (test / lint / type-check / 手動確認)
4. scope 外の発見は実装せず「実装中に分かったこと」に記録 (後で `teishutsu` の PR 本文で参照)
5. 報告を出力 → `sadoku` に handoff (報告と diff を添える)

## TDD 必要層を踏むときの分岐

純ロジック / API / バグ修正など必須レイヤーに触れる場合は計画実行を一時停止し `shiken` に入る。`kouchiku` は実装を vertical behavior slice に分解し、次に閉じる 1 slice だけを渡す。GREEN → PRUNE を終えてから次 step に戻る。

- Plan steps には候補 slice を列挙してよいが、確定扱いは次に実行する 1 slice のみ
- `shiken` return の `coverage gap` を読んで、gap を受け入れる / 次 slice にする / test level を変える を `kouchiku` が判断する
- `shiken` に後続 slice の設計や追加実装を任せない

- handoff: shiken / brief: [slice 1 文] / evidence: [関連 file:line]
- vertical slice:
  - entry: [user action / API call / public function]
  - behavior: [観測したい振る舞い]
  - observable output: [UI / response / return value / state change / persisted data]
  - excluded layers: [この cycle で通さない層]

`shiken` は「報告」(RED / GREEN / PRUNE のログ、gap、prune witness) を埋めて返してくる。

## 診断分岐

原因未確定の不具合 / 予期しない test failure / 再現不明の挙動に当たったら実装変更を止め root cause を確定する。

- root cause を 1 文で言語化できるまで実装を変更しない (`I believe the root cause is [X] because [evidence].`)
- 症状をそのまま列挙: error message / stack trace / 再現手順 / 期待値 / 実際の値
- hypothesis を 1 文にし、`diagnosis-techniques.md` を読んで instrument を 1 つだけ走らせる
- confirm → fix / `shiken` へ。discard → hypothesis 再構築。同じ症状が修正後も残れば停止して再構築
- 3 回失敗したら `hypothesis attempts / current best guess / remaining unknowns / recommended next step` を出して user の proceed 判断を求める
- fix が 5+ ファイルに touch するなら scope を確認する (= 別 bug の可能性)
- fix 後は同 input の before / after 挙動 diff を報告にそのまま引用する
- regression guard が必要なら `shiken` に渡す (root cause と再現条件を固定し、実装 discipline は委譲)
