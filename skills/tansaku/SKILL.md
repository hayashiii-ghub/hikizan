---
name: tansaku
description: "Use this skill when the user wants to understand an unfamiliar code area, gather context before design, map impact scope, inspect related files, or clarify terminology/spec gaps before implementation — including phrasings 探索して, 全体像を掴んで, この辺り見て, 影響範囲を調べて, 関連ファイルを洗って, zoom-out, すり合わせ, 仕様を詰めたい. Activate before kouchiku when the request depends on unknown code structure, domain terminology, docs/ADR context, or ambiguous acceptance criteria."
license: MIT
when_to_use: "探索, 全体像把握, 影響範囲調査, 用語整理, すり合わせ"
---

# tansaku (探索)

```
🌲 Using /tansaku for [purpose taken from trigger context].
```

調べて報告する skill。実装と設計判断はしない。設計と計画は `kouchiku`、テスト先行の実装は `shiken`、レビューは `sadoku`、提出は `teishutsu` に渡す。

<!-- hikizan:contract:start -->
## 共通ルール

全 skill 共通。`scripts/check-consistency.sh` が 6 skill で同一であることを検査する。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は docs/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / 渡すこと: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は docs/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 2 つのモード

| モード | きっかけ |
| --- | --- |
| 探索 | 「探索して」「全体像を掴んで」「この辺り見て」「影響範囲を調べて」「zoom-out」 |
| すり合わせ | 「すり合わせ」「仕様を詰めたい」「用語を整理したい」/ 探索中に、実装前に決めないと手戻りが大きい曖昧さを見つけた |

## 手順 (探索)

1. 入口文書を読む: `README.md` / `AGENTS.md` / `docs/` / ADR
2. ユーザが指定した file / dir / issue の語が出る場所を読む
3. 関連シンボルの定義・参照・呼び出し元を辿る (関数や変数は LSP、TODO やコメント等の文字列は grep。LSP が無ければ全部 grep)
4. 既存テストと検証コマンドを確認する
5. 履歴を見る:
   ```bash
   git log --oneline -20
   grep -rn "TODO\|FIXME" <関連 dir> | head -20
   ```
6. 下の「報告」を埋めて返す。確認できた事実には file:line かコマンド出力を付ける。確認できないことは推測で埋めず Unknowns に書く。構造がグラフ的 (依存 / 制御フロー / やり取り / データモデル) なら、文章でなく mermaid を 1 枚添える (`references/mermaid-views.md`)
7. 実装前に決めないと手戻りが大きい曖昧さがあれば、すり合わせに進む。小さな不明点は Unknowns に残して止まらない

## 手順 (すり合わせ)

1. 一番重要な質問を 1 つだけユーザに聞く (まとめて複数聞かない)
2. 質問には自分の推奨案を 1 行付ける
3. 回答を Map / Terminology に反映する。docs を直すべきなら更新候補として挙げる (勝手に書き換えない)
4. まだ実装前に決めるべきことが残っていれば 1 に戻る

発火条件と質問フォーマットの詳細: `references/suriawase.md`

## やってはいけないこと

- 実装コードを書く / 設計案を確定する / PR 本文を書く
- 事実と推測を混ぜる (evidence の無い行は Unknowns へ)
- 質問を一度に複数並べる

## 報告 (穴埋め)

```
Explored: [何を調べたか]
Map:
- [path:line] — [役割]
Terminology:
- [用語] = [コード/docs 上の意味] ([path:line])
Unknowns:
- [コードと docs だけでは分からないこと]
次: [kouchiku に渡す / shiken に渡す / 調査のみで完了]
```

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `suriawase.md`：すり合わせの発火条件・質問フォーマット・docs 更新の扱い
- `mermaid-views.md`：構造を mermaid で見せるときの図種別と最小例
