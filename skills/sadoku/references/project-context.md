# レビュー前の文脈抽出方針

`sadoku` の通常レビューモードで finding を判定する前に、プロジェクト文脈を確認する手順。**対象単体を読んで判断するのではなく**、それが置かれる場所のルールに沿っているかを見る。対象ファイル集合は、diff モードなら `git diff --name-only`、範囲モードなら user と確定した範囲 (`git ls-files <path>` 等) で得る。以下これを「対象ファイル」と呼ぶ。

## 6 つの確認軸

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
- ない → そもそも test を書く層か (`jikkou` の TDD reference にある層分け表で判定)

### 3. 近隣の類似実装

対象と同じ役割を持つ実装を、同 directory / module から最大 3 件選ぶ。

- 制御フロー: early return / guard / error handling の置き方
- データ変換: helper / pipeline / loop の使い分け
- 抽象化: wrapper / interface / type を切る粒度
- framework の使い方: repo 内ですでに採用されている API / pattern

比較対象は file:line で控え、`reviewer-code-quality` に渡す。
類似実装が無い場合は「比較対象なし」とし、一般的な好みを既存 convention として扱わない。

### 4. 明文化された規約 / 命名規則の踏襲

AGENTS.md / project docs / lint config から、対象に関係する規約を file:line で控える。規約が明文化されていない項目は、軸 3 の類似実装だけを根拠にする。

近隣ファイル (同 directory / 同 module) と命名スタイルが揃っているか。
- 関数: `camelCase` / `snake_case` / `PascalCase` の混在
- ファイル: `kebab-case` / `camelCase`
- 定数: `UPPER_SNAKE` / `camelCase`

近隣と違う命名が混入しているなら**未知の識別子を grep**する停止条件と同じ判定基準で扱う。

### 5. 影響範囲の見立て

diff モードは `git diff --name-only | wc -l` で touch ファイル数を把握。

| touch ファイル数 | 扱い |
|---|---|
| 1-2 | scope on target、通常レビュー |
| 3-4 | 関連 module 内で完結しているか確認 |
| **5+** | scope 確認必須、別 issue 混入を疑う (停止条件「PR 粒度違反」候補) |

範囲モードは touch 数ではなく「対象範囲が外に持つ依存の数」で blast radius を見る。範囲が広いときは subsystem 単位に割って深さを分ける。

### 6. ドメイン文脈 / 設計意図 / 脅威モデルの抽出

対象コードが「何を守り、何を意図し、何を受容しているか」を、コードを読む前に 1 か所から掴む。これが reviewer subagent の必須 input (脅威モデル / 設計意図) の出どころで、無いと採否判定が匙加減になり、懸念の羅列に落ちる。

出どころは次の優先順で 1 つに決める:

1. **CONTEXT.md** (`tansaku` が保守するドメイン文脈の正本 = 用語 / 不変条件 / 制約 / 受容済みリスク。既存のドメイン doc に畳まれているならそこ。契約は `tansaku` の context-doc reference)
2. 無ければ **PR / issue の intent** (本文・DoD・リンクされた ADR)
3. それも無ければ **user に 1 行で聞く** (「このコードは何を守る前提?」)。憶測で脅威モデルを作らない

抽出した前提は persona 起動時にそのまま渡す (`persona-catalog.md` の「起動の流れ」3)。CONTEXT.md と実装がズレていたら、それ自体を finding にする。`reviewer-code-quality` には軸 3 の比較対象と軸 4 の規約の出典も渡す。

## 出力

確認結果を sadoku の報告に反映する。diff モードで drift があれば「実装中に分かったこと」記載を提案。近隣の比較対象、関連する repo convention の出典、抽出したドメイン文脈 / 設計意図 / 脅威モデルは reviewer subagent の input として渡す。

## やらないこと

- file ごとに全行を音読しない (意味的単位で読む)
- 対象外ファイルの読み込みは、依存関係解決に必要な最小限のみ
- 「念のため」の grep を 3 回以上連発しない (= scope を見失ってる兆候、戻る)
