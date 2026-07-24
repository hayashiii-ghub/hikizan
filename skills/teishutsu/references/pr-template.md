# PR 本文ドラフト

`teishutsu` が PR 作成前に読む reference。出力は 6 セクション固定。これが hikizan の出口契約。どの進め方で実装しても、PR はこの形に収束させる。

## 目次

- [Intake](#intake)
- [Procedure](#procedure)
- [Stop Conditions](#stop-conditions)
- [PR Title](#pr-title)
- [Output Template](#output-template)
- [Granularity](#granularity)
- [Writing Checks](#writing-checks)
- [Structure Preference](#structure-preference)
- [PII / Secrets scan](#pii--secrets-scan)

## Intake

必須:
- issue / 計画 / change intent のいずれか
- diff または変更ファイル一覧
- 検証コマンドまたは手動確認内容

不足時:
- 推測で本文を埋めない
- 欠けている項目だけ確認する

## Procedure

1. issue / 計画から「課題」と「DoD」を抽出し、タイトルを `naming.md` (同 dir) の規則で 1 行決める
2. diff または計画から「実装の流れとレビュー順」を作る
3. scope 外発見を「実装中に分かったこと」へ分ける
4. 検証コマンドと手動確認シナリオを列挙する
5. 粒度を確認する
6. Workflow 節を埋める (実際にやったことだけ書く。やっていない工程は「なし」)
7. 文章チェックを適用する
8. PII / Secrets scan を行う
9. 6 セクション本文を出す

## Stop Conditions

- 必須 intake が欠けている
- diff が複数 issue に跨いでいる
- PII / Secrets が本文、commit message、release notes に混入している
- 検証結果が不明なのに「検証済み」と書こうとしている

## PR Title

タイトルは `naming.md` の識別子規範に従う。
hikizan は squash merge なので、PR タイトルはそのまま main の commit subject になる。

- 命令形か現在形で「何が変わるか」を機能名で 1 行 (例: `add naming norm doc`)。
- 連番 (`PR-1`) を付けない。prefix は `naming.md`「commit subject」の scope prefix 規約に従う (`<scope>: <本文>` 可、`feat(x):` 形は不可)。
- 末尾の `(#NN)` は squash 時に GitHub が自動付与するので手で書かない。

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

## Workflow

- 探索: [調べた範囲と主要な発見 1 行 / なし]
- 設計: [選んだ案と、見送った案 1 行 / なし]
- 実装: [TDD なら RED→GREEN→PRUNE の test runner 最終行。TDD でなければ何をどう検証したか]
- レビュー: [停止条件チェックの結果 / failure scenario 1 行 / なし]
- 判断メモ: [迷って自分で決めたことと根拠 / なし]
````

Workflow 節は「過程の trace」。読む人がここだけ見れば、どのモデル・どの進め方で作った PR でも何が起きたか分かる状態にする。検証ログの引用は要約せずそのまま貼る。

## Granularity

- 1 issue = 1 PR
- 実装中に発見した別問題は scope に含めず、「実装中に分かったこと」に記録する
- 関連性があっても、別 issue として独立して動く粒度なら分割
- diff が複数 issue に跨いでいたら停止する

## Writing Checks

PR本文の日本語は `houkoku` のwriting-style referenceに従う。次の可読性チェックはその要点。

1. **結論先出し**：1 文目で「何が変わったか」が分かる
2. **1 段落 1 主張**：読み手に並列処理させない
3. **語彙が読み手のもの**：チーム / 外部レビュアーが知ってる言葉か
4. **儀礼削除**：「まず最初に」「以上、よろしくお願いします」は技術文に不要

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

`teishutsu`と`sadoku`が共通で参照するrecipe。repo既存のsecret scannerは、対象repoがuser-trustedで、scanner本体・設定・依存がreview rangeに含まれず、network / hook / pluginを実行しないと内容を読んで確認できた場合だけ使う。外部PR、出所不明、またはscanner関連fileが変更対象なら実行せず、下のbuilt-in grepへ落とす。

mode 700の一時directoryを作った直後に、directory pathを空にして二重実行を無害化する`cleanup`を`EXIT`へ登録する。`HUP / INT / TERM`は各trapを解除し、cleanup後に129 / 130 / 143で明示終了するhandlerへ分け、interrupt後の処理を続行しない。次をmode 600の別fileとして用意する。各fileを出力前に同じpatternでgrepし、保存前に既知のsecret値をredactする。

- PR body / review report
- 固定したrangeのcommit message
- release notes変更
- 本文へ転載するdiff・検証ログ

```bash
# email
grep -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' <draft>
# token-like
# hikizan:token-pattern
grep -E '(sk-(proj-)?[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{16,}|xox[baprs]-[A-Za-z0-9-]{16,}|A(SI|KI)A[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|Authorization:[[:space:]]*(Basic|Bearer)[[:space:]]+[A-Za-z0-9._~+/-]{8,}|-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----)' <draft>
# 個人名 (チーム外の実名)
# → 人手確認、機械では完全には判定できない
```

genericな`secret` / `password` assignmentとチーム外の実名は人手確認する。成功・失敗・interruptの全経路で一時directoryを削除する。0件でも報告に、scanした入力種別と`PII scan: clean (0 matches)`、grep出力を記載する。
