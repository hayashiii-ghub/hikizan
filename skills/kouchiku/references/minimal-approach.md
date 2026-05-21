# minimal-approach

引き算プロトコル本体。kouchiku 通常検討モードの出力に必須の `Minimal Approach:` セクションと、推奨度 N/10 の付け方を定義する。他 skill (sadoku findings の disposition / teishutsu の PR 規模判定 等) からも参照する。

## 推奨度の付け方

- `N/10 + 1 行根拠` を必須化 (数値だけだと検証不能)
- 例: `Approach: 案 A (8/10) — 既存 module の依存方向に沿う、変更点が局所的`
- 「9/10 と 8/10 の差を 1 行で説明できない」なら数値を下げて根拠を明示

## Minimal Approach の判定

通常検討モードの出力 (`Plan steps:` の後) に `Minimal Approach:` を必ず添える。判定手順:

1. **素直な規模を概算**: issue 文の動詞 (「追加する」「換装する」「修正する」等) と名詞句を抽出し、対応するファイル数 / 行数 / step 数を見積もる。例: 「README に install 節を追加」→ 1 ファイル、~30 行、1 step が素直
2. **plan の規模と対比**:
   - 素直な規模の **2 倍以上** → 引き算した最小版を併記し、defer 項目を明示する
   - **2 倍未満** → "minimal already" と 1 行で宣言する
3. **defer 項目の書き方**: 「何を別 issue に切り出したか」「なぜ defer か (コスト / リスク / 別 issue 値の 3 軸)」を 1 行ずつ

### 出力例

素直な規模の 3 倍になった plan:

```
Minimal Approach:
  本 plan は 6 step / 9 ファイル / 約 360 行で、issue 文の素直な規模 (2 step / 3 ファイル / 約 120 行) の 3 倍。
  最小版:
    - step 1 (対象関数の rename) のみを 1 PR で出す
    - これだけで issue 文の要求は満たせる
  defer した項目:
    - step 2-4 (呼び出し側の一括整理) → 別 issue (理由: issue 文に無い改善で本 plan の出荷を遅らせる)
    - step 5-6 (新規 helper の抽出) → 重複が 3 箇所以上に増えてから (理由: 早すぎる抽象化を避ける)
```

素直な規模に近い plan:

```
Minimal Approach: minimal already (素直な規模 N step に対し本 plan も N step、defer なし)
```

## なぜ引き算が要るか

LLM agent は「丁寧に網羅する」方向に偏りやすい。issue 文の素直な要求を素通りして、周辺の改善案 / リファクタ / 未来の拡張案を勝手に拾ってくる。引き算プロトコルはこの傾向に対する強制的な校正点。

- 計画策定段階: `Minimal Approach:` で素直な規模との対比を強制
- 推奨度: N/10 + 1 行根拠で「なんとなく良さそう」案の混入を抑止
- 3 案禁止: paralysis 防止、選択肢爆発の予防

## 関連

- `skills/kouchiku/SKILL.md` Hard Rules — 命名規約側の引き算
