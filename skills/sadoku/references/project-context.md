# レビュー前の文脈抽出方針

`sadoku` の通常レビューモードで対象 (diff または指定範囲のコード) を読む前に、プロジェクト文脈を確認する手順。**対象単体を読んで判断するのではなく**、それが置かれる場所のルールに沿っているかを見る。対象ファイル集合は、diff モードなら `git diff --name-only`、範囲モードなら user と確定した範囲 (`git ls-files <path>` 等) で得る。以下これを「対象ファイル」と呼ぶ。

## 5 つの確認軸

### 1. ファイル単位の依存関係

対象ファイルの import / export を grep で把握する。

```bash
# 対象ファイルが export するシンボル
# (diff モードは git diff --name-only、範囲モードは git ls-files <path> に置き換える)
git diff --name-only | xargs grep -E '^export ' 2>/dev/null

# それらのシンボルが他のどこから import されているか
SYMBOL=foo
grep -rn "import.*$SYMBOL\|from.*$SYMBOL" --include='*.ts' --include='*.tsx' .
```

未把握の caller がいないか、変更が破壊的でないかを判定する材料。範囲モードでは「その範囲が外へ公開している API と、外から呼ばれている数」を掴む。

### 2. 既存のテスト構造

対象に対応する `*.test.{ts,tsx}` の有無と命名規則。

- ある → 同じ命名・配置・書き方で追加されているか
- ない → そもそも test を書く層か (`skills/jikkou/references/tdd.md` の層分け表で判定)

### 3. 命名規則の踏襲

近隣ファイル (同 directory / 同 module) と命名スタイルが揃っているか。
- 関数: `camelCase` / `snake_case` / `PascalCase` の混在
- ファイル: `kebab-case` / `camelCase`
- 定数: `UPPER_SNAKE` / `camelCase`

近隣と違う命名が混入しているなら**未知の識別子を grep**する停止条件と同じ判定基準で扱う。

### 4. 影響範囲の見立て

diff モードは `git diff --name-only | wc -l` で touch ファイル数を把握。

| touch ファイル数 | 扱い |
|---|---|
| 1-2 | scope on target、通常レビュー |
| 3-4 | 関連 module 内で完結しているか確認 |
| **5+** | scope 確認必須、別 issue 混入を疑う (停止条件「PR 粒度違反」候補) |

範囲モードは touch 数ではなく「対象範囲が外に持つ依存の数」で blast radius を見る。範囲が広いときは subsystem 単位に割って深さを分ける。

### 5. ドメイン文脈 / 設計意図 / 脅威モデルの抽出

対象コードが「何を守り、何を意図し、何を受容しているか」を、コードを読む前に 1 か所から掴む。これが reviewer subagent の必須 input (脅威モデル / 設計意図) の出どころで、無いと採否判定が匙加減になり、懸念の羅列に落ちる。

出どころは次の優先順で 1 つに決める:

1. **CONTEXT.md** (`tansaku` が保守するドメイン文脈の正本 = 用語 / 不変条件 / 制約 / 受容済みリスク。既存のドメイン doc に畳まれているならそこ。契約は `skills/tansaku/references/context-doc.md`)
2. 無ければ **PR / issue の intent** (本文・DoD・リンクされた ADR)
3. それも無ければ **user に 1 行で聞く** (「このコードは何を守る前提?」)。憶測で脅威モデルを作らない

抽出した前提は persona 起動時にそのまま渡す (`persona-catalog.md` の「起動の流れ」3)。CONTEXT.md と実装がズレていたら、それ自体を finding にする。

## 出力

確認結果を sadoku の報告に反映する。diff モードで drift があれば「実装中に分かったこと」記載を提案。抽出した ドメイン文脈 / 設計意図 / 脅威モデルは reviewer subagent の必須 input として渡す。

## やらないこと

- file ごとに全行を音読しない (意味的単位で読む)
- 対象外ファイルの読み込みは、依存関係解決に必要な最小限のみ
- 「念のため」の grep を 3 回以上連発しない (= scope を見失ってる兆候、戻る)
