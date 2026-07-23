# レビュー前の文脈抽出方針

`sadoku` の通常レビューモードで finding を判定する前に、プロジェクト文脈を確認する手順。**対象単体を読んで判断するのではなく**、それが置かれる場所のルールに沿っているかを見る。

diffモードは開始時にdescriptorを1つ固定し、対象一覧・行数・本文・PII scanを同じmappingから得る。実装後の通常handoffはmixed stateを落とさない`BRANCH_SNAPSHOT`を既定にする。

| REVIEW_KIND | 固定値 | tracked対象 | untracked対象 |
| --- | --- | --- | --- |
| `BRANCH_SNAPSHOT` | `REVIEW_BASE=<merge-base>` | `git diff --name-only -z "$REVIEW_BASE" --` (commit済み + staged + unstaged) | `git ls-files --others --exclude-standard -z` |
| `COMMIT_RANGE` | `COMMIT_RANGE=<base>...HEAD` | `git diff --name-only -z "$COMMIT_RANGE" --` | 含めない (PRに入らないため) |
| `INDEX` | `INDEX` | `git diff --cached --name-only -z --` | 含めない |
| `WORKTREE` | `WORKTREE` | `git diff --name-only -z --` | `git ls-files --others --exclude-standard -z` |

untracked fileはdiffが無いため全内容をadditionとして読み、行数・PII・依存確認へ加える。`BRANCH_SNAPSHOT`では4状態のどれかが空でも同じdescriptorを保つ。範囲モードはuserと確定したpathを`git ls-files <path>`等で得る。以下これを「対象ファイル」と呼ぶ。

## 6 つの確認軸

### 1. ファイル単位の依存関係

code は対象ファイルの import / export、実行仕様 Markdown は参照先・生成元・生成先・handoff先を把握する。

```bash
# COMMIT_RANGEがexportするsymbol。NUL区切りでfilenameをdataとして扱う
while IFS= read -r -d '' file; do
  grep -E '^export ' -- "$file"
done < <(git diff --name-only -z "$COMMIT_RANGE" --)

# それらのシンボルが他のどこから import されているか
SYMBOL=foo
grep -rn "import.*$SYMBOL\|from.*$SYMBOL" --include='*.ts' --include='*.tsx' .
```

未把握の caller / consumer がいないか、変更が破壊的でないかを判定する材料。実行仕様 Markdown では marker の生成script、同じ規則を転記した文書、存在しない handoff を grep する。範囲モードでは「その範囲が外へ公開している API / instruction と、外から参照される数」を掴む。

### 2. 既存のテスト構造

code は対応するtest、実行仕様 Markdown は生成鮮度check・consistency lint・recipeの回帰fixtureを確認する。

- ある → 同じ命名・配置・書き方で追加されているか
- ない → そもそも test を書く層か (`jikkou` の TDD reference にある層分け表で判定)

### 3. 近隣の類似実装

対象と同じ役割を持つ実装 / instruction artifact を、同 directory / module から最大 3 件選ぶ。

- 制御フロー: early return / guard / error handling の置き方
- データ変換: helper / pipeline / loop の使い分け
- 抽象化: wrapper / interface / type を切る粒度
- framework の使い方: repo 内ですでに採用されている API / pattern
- 実行仕様: mode / 手順 / stop / handoff / report の順序と粒度、SoTと生成blockの分離

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

diffモードは上表のtracked対象とuntracked対象をNUL区切りのまま和集合にし、重複を除いてtouchファイル数を把握する。

| touch ファイル数 | 扱い |
|---|---|
| 1-2 | scope on target、通常レビュー |
| 3-4 | 関連 module 内で完結しているか確認 |
| **5+** | scope 確認必須、別 issue 混入を疑う (停止条件「PR 粒度違反」候補) |

範囲モードは touch 数ではなく「対象範囲が外に持つ依存の数」で blast radius を見る。範囲が広いときは subsystem 単位に割って深さを分ける。

### 6. ドメイン文脈 / 設計意図 / 脅威モデルの抽出

対象artifactが「何を守り、何を意図し、何を受容しているか」を、対象を読む前に1か所から掴む。これが reviewer subagent の必須 input (脅威モデル / 設計意図) の出どころで、無いと採否判定が匙加減になり、懸念の羅列に落ちる。

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
