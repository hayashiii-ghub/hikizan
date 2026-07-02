---
name: shiken
description: "Use this skill when implementing behavior or fixing bugs in pure logic, business rules, API behavior, or build/CI logic — anywhere a regression would be costly. The skill enforces TDD discipline: failing test first, witness fail, implement minimally, PRUNE after green. Phrasings include TDDで, テストから書いて, テスト先行. Activate when fixing a bug that needs a regression guard or adding logic to untested code — even without explicit 'TDD' wording. 対象は root cause が既知の実装・修正。原因不明のバグはまず jikkou (診断) に渡す。"
license: MIT
when_to_use: "TDD, テスト先行, テストから書く"
---

# shiken (試験)

```
🌲 Using /shiken for [purpose taken from trigger context].
```

> **テストが先。fail を見るまで実装を書かない。「あとで書く」「手で確認した」は理由にならない。**

テスト先行で 1 つの振る舞いを実装する skill。slice の分解は `jikkou`、設計判断は `sekkei` に渡す。

<!-- hikizan:contract:start -->
## 共通ルール

core 7 skill (init を除く全 skill) 共通。`scripts/check-consistency.sh` が 7 skill で同一であることを検査する。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は docs/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は docs/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 手順

1. slice を 1 文で書く: 「[入力 / 操作] のとき [観測できる出力] になる」。1 文にできなければ実装に入らず `jikkou` に返す。`jikkou` からの handoff に slice が無いときも差し戻す
2. **RED**: その slice が失敗するテストを 1 つ書き、test runner を実行して fail の出力を見る (最終行を控える)
3. **GREEN**: テストを pass させる最小の実装を書き、test runner を実行して pass の出力を見る
4. **REFACTOR**: 重複除去と命名改善をする。テストは green のまま保つ
5. **PRUNE**: 残すテストを slice の振る舞い基準で選び、不要なテストを消す (判定 5 問は `references/testing-anti-patterns.md`)。原則 1 slice = 残すテスト 1 つ
6. **PRUNE 検証**: 残した各テストについて、実装の observable output を一時的に壊す → テストが fail することを見る → 元に戻す → pass を見る → `git status` が clean なことを確認する
   ```bash
   cp path/to/impl /tmp/hikizan-prune.impl
   # observable output だけを一時的に壊す → test runner で fail を見る
   cp /tmp/hikizan-prune.impl path/to/impl
   # test runner で pass を再確認 → git status で clean を確認
   ```
7. 下の「報告」を埋めて呼び出し元に返す。テストの足りない振る舞い (gap) に気づいても、勝手に次の slice を始めず gap として書いて返す

## テスト先行が必須の変更 / skip してよい変更

| 変更の種類 | 例 | 扱い |
| --- | --- | --- |
| 純ロジック | validator / formatter / reducer / store | **必須** |
| ビジネスルール | 価格計算 / 権限判定 / 状態遷移 | **必須** |
| バグ修正 (全レイヤー) | 再現テストを先に書く | **必須** |
| API 層 | client / query / data transform | **必須** (mock 境界を明示) |
| 設定 / build / CI | manifest / build 設定 / workflow | **必須** (実行ログで動作確認) |
| インタラクション | event → state / form submit | 推奨 |
| 純スタイル / 文言 / asset | spacing / i18n / icon | skip 可 (報告に理由を 1 行書く) |

skip した後でもロジック行に 1 行でも触れたら必須に戻る。

## やってはいけないこと

- fail を見る前に実装コードを書く
- RED / GREEN の実行を subagent に投げる (自分の目で出力を見る)
- mock の存在や呼び出し回数を assert する
- テストのためだけの method を production class に足す
- 理由を書かずにテストを skip する
- 2 つ目の slice を勝手に始める (gap は報告に書いて呼び出し元に返す)
- private な内部形状に assert を向ける (slice の observable output に向ける)
- PRUNE 検証で壊した実装を戻し忘れる (`git status` clean を確認するまで終わらない)

## 報告 (穴埋め)

最初に結論を 1 文。続けて TDD サイクルのログを残す。RED / GREEN はコマンド出力の最終行をそのまま貼る。

[1 文: どの振る舞いを実装し、テストが通っているか]

- slice: [入力 / 操作] のとき [観測できる出力] になる
- test level: [unit / integration / component / e2e]、[選んだ理由 1 行]
- RED: [test runner の最終行 (fail を含む)]
- GREEN: [test runner の最終行 (pass)]
- PRUNE: [N 残し M 削除] / witness: [何を壊して fail を見たか]
- restore: [git status --short の出力 / "clean"]
- gap: [テストしていない振る舞い / なし]
- skip: [skip した変更と理由 1 行 / なし]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `testing-anti-patterns.md`：PRUNE の判定 5 問と anti-pattern 集
