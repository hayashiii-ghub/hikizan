# 通常検討モードの手順

`kouchiku` SKILL.md の「通常検討」出力契約を満たすための既定手順。standard tier は invariant (前提崩し・前提リスク検証を埋める / 命名規約 / 3 案以上禁止) を保ったまま圧縮してよい。guided tier はこの順序で進める。

## 思考の手順

1. **問題定義**: 何を解決するか、何を解決しないか (out-of-scope) を分ける
2. **推奨案を 1 つ**: file:line / 関連 module / 影響範囲を具体的に
3. **代替案は近接時のみ 1 つ**: 推奨と近く議論する価値があるものだけ。遠い案は出さない
4. **前提崩し**: この設計が前提とする事実を 3-5 個列挙し、各々が崩れたらどうなるかを評価
5. **前提リスク検証**: この案を採用した 6 ヶ月後に問題化しうるシナリオを 1 つ書く
6. **計画化**: 計画実行モードに渡せる形 (step / owner skill / file / 検証コマンド) で出力

## 出力形式

```
Building:        [何を作る、1 段落]
Not building:    [out-of-scope、1-3 項目]
Approach:        [選んだ案、推奨度 N/10 + 1 行根拠]
Alternatives:    [近接時のみ、各案に推奨度 N/10 + 1 行根拠。明確なら 1 案でよい]
Structure:       [任意] 構造変更 (module 境界 / 依存 / data flow) を伴う時だけ
                 before/after を mermaid 1 枚。線形手順は箇条書きで足りる
Key decisions:   3-5 項目 (各「ほかの選択肢を採らなかった理由」を 1 行)
Interface sketch: [任意] 最も load-bearing な interface 1 点を signature / data 形で
                 (実在 symbol を file:line 付きで参照、~5-8 行、logic 本体なし)
Premises:        依存している事実 3-5 個 (各 ✓ file:line で確認済 / ⚠ 未検証)
Worst case:      6 ヶ月後に問題化しうるシナリオ
Unknowns:        defer 理由 + 担当明記の項目のみ
Plan steps:      実装単位 (owner skill / file / 検証コマンド。TDD 必要層は
                 next slice / candidate follow-up slices を分ける)
Minimal Approach: 下記判定に従い最小版を併記 or "minimal already"
```

## Minimal Approach の判定

`Minimal Approach:` を書く前に `minimal-approach.md` を読む。

- issue 文の動詞 (「追加する」「換装する」等) と名詞句を抽出し、要求から直接読める規模 (ファイル数 / 行数 / step 数) を概算する
- plan が要求から直接読める規模の 2 倍以上 → 引き算した最小版を併記し、defer した項目を明示
- 2 倍未満 → "minimal already" と明記

## Structure 図 / Interface sketch の指針 (どちらも任意)

- **Structure 図**: 構造変更を伴う時だけ mermaid。線形手順は箇条書きで足りる
- **Interface sketch**: 1 plan に 1 つ、最も load-bearing な境界のみ。approach 選定後に書く。実在 symbol を `file:line` で参照 (grounded、invent 不可)。logic 本体は書かない (要るなら実装 → `Unknowns` に defer)
- sketch は「signature を綺麗に書けない = 設計未確定」を plan 時点で炙り出す forcing function
