jikkou の TDD 実装モードの詳細。SKILL.md の「手順 (TDD 実装)」の各 step を補足する。

> **テストが先。fail を見るまで実装を書かない。「あとで書く」「手で確認した」は理由にならない。**

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

## RED → GREEN → REFACTOR → PRUNE の詳細

1. slice を 1 文で書く: 「[入力 / 操作] のとき [観測できる出力] になる」。1 文にできなければ実装に入らない
2. **RED**: その slice が失敗するテストを 1 つ書き、test runner を実行して fail の出力を見る (最終行を控える)
3. **GREEN**: テストを pass させる最小の実装を書き、test runner を実行して pass の出力を見る
4. **REFACTOR**: 重複除去と命名改善をする。テストは green のまま保つ
5. **PRUNE**: 残すテストを slice の振る舞い基準で選び、不要なテストを消す (判定 5 問は `testing-anti-patterns.md`)。原則 1 slice = 残すテスト 1 つ
6. **PRUNE 検証**: 残した各テストについて、実装の observable output を一時的に壊す → テストが fail することを見る → 元に戻す → pass を見る → `git status` が clean なことを確認する
   ```bash
   cp path/to/impl /tmp/hikizan-prune.impl
   # observable output だけを一時的に壊す → test runner で fail を見る
   cp /tmp/hikizan-prune.impl path/to/impl
   # test runner で pass を再確認 → git status で clean を確認
   ```
7. 下の「報告」(SKILL.md) を埋めて呼び出し元 (計画実行 / 診断) に返す。テストの足りない振る舞い (gap) に気づいても、勝手に次の slice を始めず gap として書いて返す

## やってはいけないこと (TDD 実装固有)

- mock の存在や呼び出し回数を assert する
- テストのためだけの method を production class に足す
- 理由を書かずにテストを skip する
- private な内部形状に assert を向ける (slice の observable output に向ける)
- PRUNE 検証で壊した実装を戻し忘れる (`git status` clean を確認するまで終わらない)

## references/

- `testing-anti-patterns.md`：PRUNE の判定 5 問と anti-pattern 集
