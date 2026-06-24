# diff 読解時の文脈抽出方針

`sadoku` の通常レビューモードで diff を読む前に、プロジェクト文脈を確認する手順。**diff 単体を読んで判断するのではなく**、その diff が置かれる場所のルールに沿っているかを見る。

## 4 つの確認軸

### 1. ファイル単位の依存関係

変更ファイルの import / export を grep で把握する。

```bash
# 変更ファイルが export するシンボル
git diff --name-only | xargs grep -E '^export ' 2>/dev/null

# それらのシンボルが他のどこから import されているか
SYMBOL=foo
grep -rn "import.*$SYMBOL\|from.*$SYMBOL" --include='*.ts' --include='*.tsx' .
```

未把握の caller がいないか、変更が破壊的でないかを判定する材料。

### 2. 既存のテスト構造

変更対象に対応する `*.test.{ts,tsx}` の有無と命名規則。

- ある → 同じ命名・配置・書き方で追加されているか
- ない → そもそも test を書く層か (`shiken` の層分け表で判定)

### 3. 命名規則の踏襲

近隣ファイル (同 directory / 同 module) と命名スタイルが揃っているか。
- 関数: `camelCase` / `snake_case` / `PascalCase` の混在
- ファイル: `kebab-case` / `camelCase`
- 定数: `UPPER_SNAKE` / `camelCase`

近隣と違う命名が混入しているなら**未知の識別子を grep**する停止条件と同じ判定基準で扱う。

### 4. 変更影響範囲の見立て

`git diff --name-only | wc -l` で touch ファイル数を把握。

| touch ファイル数 | 扱い |
|---|---|
| 1-2 | scope on target、通常レビュー |
| 3-4 | 関連 module 内で完結しているか確認 |
| **5+** | scope 確認必須、別 issue 混入を疑う (停止条件「PR 粒度違反」候補) |

## 出力

確認結果を sadoku の報告に反映する。drift があれば「実装中に分かったこと」記載を提案。

## やらないこと

- file ごとに全行を音読しない (diff の意味的単位で読む)
- 未変更ファイルの読み込みは、依存関係解決に必要な最小限のみ
- 「念のため」の grep を 3 回以上連発しない (= scope を見失ってる兆候、戻る)
