# PR 本文ドラフト

`teishutsu` が PR 作成前に読む reference。出力は 5 セクション固定。

## Intake

必須:
- issue / 計画 / change intent のいずれか
- diff または変更ファイル一覧
- 検証コマンドまたは手動確認内容

不足時:
- 推測で本文を埋めない
- 欠けている項目だけ確認する

## Procedure

1. issue / 計画から「課題」と「DoD」を抽出する
2. diff または計画から「実装の流れとレビュー順」を作る
3. scope 外発見を「実装中に分かったこと」へ分ける
4. 検証コマンドと手動確認シナリオを列挙する
5. 粒度を確認する
6. 文章チェックを適用する
7. PII / Secrets scan を行う
8. 5 セクション本文を出す

## Stop Conditions

- 必須 intake が欠けている
- diff が複数 issue に跨いでいる
- PII / Secrets が本文、commit message、release notes に混入している
- 検証結果が不明なのに「検証済み」と書こうとしている

## Output Template

````markdown
## 課題

[背景・現状の問題、1-2 段落]

[この PR では、〜します の 1 文で結論先出し]

## DoD

- [完了基準を bullet で、各項目 testable]

## 実装の流れとレビュー順

1. [step 1 のタイトル]

   - File: `path/to/file.ext`
   - Change: [何を変えたか、過去形「〜しました」]
   - Review: [何を確認すべきか、「〜を確認してください」]

2. [step 2 のタイトル]

   - File: `...`
   - Change: ...
   - Review: ...

## 実装中に分かったこと

- [副次的に判明したこと]
- [scope 外と判断して別 issue / 別 PR に切り出したこと、PR 番号があれば参照]

## 検証

- `yarn exec tsc --noEmit --incremental false --pretty false`
- 変更ファイルに対する `yarn exec biome check`
- ブラウザでの手動会話テスト

手動確認:

- [具体的なテストシナリオ]
````

## Granularity

- 1 issue = 1 PR
- 実装中に発見した別問題は scope に含めず、「実装中に分かったこと」に記録する
- 関連性があっても、別 issue として独立して動く粒度なら分割
- diff が複数 issue に跨いでいたら停止する

## Writing Checks

1. **結論先出し** — 1 文目で「何が変わったか」が分かる
2. **1 段落 1 主張** — 読み手に並列処理させない
3. **語彙が読み手のもの** — チーム / 外部レビュアーが知ってる言葉か
4. **儀礼削除** — 「まず最初に」「以上、よろしくお願いします」は技術文に不要

不可:
- 「自然な文章」のような抽象指示だけで終える
- AI 臭リストを作る
- 単語狩りで本文品質を判定する

## Structure Preference

| 情報 | 優先形式 |
|---|---|
| 実装 step が 5+ | mermaid flowchart |
| 変更前後の対比 | before / after 表 |
| データ構造の変更 | box diagram |
| 判断理由 | 短い本文 |

## PII / Secrets scan

`teishutsu` と `sadoku` が共通で参照する recipe。出力前に最低限以下を grep:

```bash
# email
grep -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' <draft>
# token-like
grep -E '(sk-|ghp_|ghs_|xox[bao]p)-?[A-Za-z0-9_]{16,}' <draft>
# 個人名 (チーム外の実名)
# → 人手確認、機械では完全には判定できない
```

0 件でも完了記録に `PII scan: clean (0 matches)` と検証ログを記載する。
