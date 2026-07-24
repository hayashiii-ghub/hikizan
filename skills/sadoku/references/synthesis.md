# synthesis (統合) の出口契約

複数 reviewer の構造化データを、user に返す 1 本のレビューへ統合する controller (sadoku 本体) の手順。**入口が diff でもプロジェクト全体でも、出口はこの形で揃える**。これがレビューの質を LLM の匙加減から契約に移す層になる。

subagent または inline persona は軸ごとの構造化データ (finding + 判定 + severity + ripple + 該当なし) を返すだけ。優先順位づけ・重複排除・翻訳・総評は persona に持たせず、ここで controller が一度だけやる。

## 入力

- 各 reviewer の出力 (code-quality / security / architecture / …)。native subagent と inline fallback を同じ扱いにする
- controller 自身が diff / コードを裏取りした結果 (subagent の finding は裏取り済みのものだけ採用)
- 対象に渡した脅威モデル / 設計意図 (採否判定の基準として再掲するため)

## 手順

1. **裏取りで選別**：各 finding を controller が該当 file:line で確認。再現できないもの・前提を取り違えているものは落とす。残ったものだけ統合対象にする
2. **重複排除**：同一 file:line / 同一根本原因を指す finding を 1 件にまとめる。軸をまたいだ重複 (security と architecture が同じ箇所を別angleで指摘) は「1 件・複数軸」として束ねる
3. **採否で仕分け**：各 finding を `受容妥当` と `直す価値あり` に分ける。判定は渡された脅威モデル / 設計意図に照らす (reviewer の判定を controller が追認 or 上書きする。上書きしたら理由を 1 行)
4. **軸横断で優先順位づけ**：`直す価値あり` を severity × blast radius (ripple の実数) で並べ、top-N を順序つきにする。各findingに `owner skill` (`jikkou` / `sekkei`) を付け、局所修正は `jikkou`、設計判断・module境界・方針変更は `sekkei` にする
5. **読者に合わせて翻訳**：専門用語を、報告を読む相手に合わせて噛み砕く (初学者なら「timing attack = 応答時間の差から秘密を推測される」等)。severity が文脈依存なら dual のまま出す (個人利用:低 / 公開:高)
6. **verdict を 1 行**：健全性・隔離強度の TL;DR を 1 文で書く (例:「ホストは守れる / 箱に渡した認証情報は守れない」)。high signal の一言を最初に置く
7. **アクションメニューで閉じる**：user に次の一手を選ばせる (下記)

## 出口フォーマット (user 向け)

```
[verdict: 健全性・リスクの TL;DR を 1 文]

## 直す価値あり (優先順)
1. [severity] file:line — [issue を平易に] / 影響: [ripple の実数] / owner skill: [jikkou / sekkei] / 対応: [recommend]
2. ...

## 受容妥当 (今回は直さなくてよい)
- file:line — [なぜ受容してよいか、渡された前提に照らして 1 行]

## 該当なし (見て clean だった軸)
- [軸: 該当なし]  ← subagent の「該当なし」を集約。"そもそも見たのか" の疑念を消す

## 次どうする
- [ ] owner skill ごとに top-N を `jikkou` / `sekkei` へ渡す
- [ ] 一部だけ直して残りは別 issue 化
- [ ] 全部受容してこのまま出す (teishutsu へ)
```

## やらないこと

- subagent の出力をそのまま貼らない (統合が controller の仕事。貼るだけなら synthesis していない)
- 裏取りしていない finding を top-N に載せない
- 「該当なし」を省かない (clean だった軸こそ明示する)
- severity を勝手に一本化しない (文脈依存なら dual を保つ)
