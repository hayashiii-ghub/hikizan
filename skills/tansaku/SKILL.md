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

情報取得、構造把握、用語整理、未決事項の確認を扱う。`tansaku` は判断と実装をしない。設計判断 / 計画化 / 実装は `kouchiku`、TDD は `shiken`、レビューは `sadoku`、提出は `teishutsu` に渡す。

`tansaku` は `zoom-out` と `grill-with-docs` 相当を 1 skill 内の mode として扱う。まず探索で事実を集め、実装前に決めないと手戻りが大きい曖昧さが見つかった場合だけ、すり合わせ mode に自動遷移する。

## Step 0: worktree 検出

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較する。異なれば worktree 内 — branch 名とともに表示し、完了記録の `worktree` 行に記録する。worktree の作成・削除はこの skill では行わない。

## モード切替

| モード | 入力トリガー | 状態トリガー | 動作 |
| --- | --- | --- | --- |
| 探索 | `探索して` / `全体像を掴んで` / `この辺り見て` / `影響範囲を調べて` / `関連ファイルを洗って` / `zoom-out` | 未知領域 / 影響範囲不明 / kouchiku 前の文脈不足 | コード・docs・履歴から Map / Terminology / Unknowns を作る |
| すり合わせ | `すり合わせ` / `仕様を詰めたい` / `用語を整理したい` | 探索中に実装前確認が必要な曖昧さを検出 | 一問ずつ確認し、推奨案と docs 更新候補を出す |
| handoff | なし | 探索またはすり合わせ完了 | `kouchiku` / `shiken` / `none` への brief を作る |

探索 mode からすり合わせ mode への自動遷移は、確認が必要な場合だけ行う。軽微な不明点は `Unknowns` に残し、作業を止めすぎない。

## 探索モード

コード領域の地図を作る。設計案を確定せず、事実と推測を分ける。

**読む順序**

1. 入口文書: `README.md`, `AGENTS.md`, `docs/`, `CONTEXT.md`, `docs/adr/`
2. ユーザー指定の file / dir / issue 文に出る語
3. 関連シンボルの定義・参照・呼び出し元
4. 既存テスト / 検証コマンド
5. 周辺履歴: recent commits, newly added files, TODO / FIXME

**探索コマンドの例**

```bash
git log --oneline -20
git submodule foreach 'git log --oneline -5' 2>/dev/null
grep -rn "TODO\|FIXME" <関連 dir> | head -20
git log --diff-filter=A --name-only -10 | head -30
```

シンボル探索 (関数 / クラス / 変数の定義 / 参照) は LSP を優先、テキスト探索 (TODO / FIXME / 設定 / Markdown / コメント内文字列) は grep を使う。LSP 未設定環境では grep にフォールバックする。

**出力形式**

```
Explored: [対象領域 / 依頼内容]
worktree: in-worktree / normal-repo

Map:
- entry points:
  - [path:line] — [入口の役割]
- core modules:
  - [path:line] — [中核責務]
- upstream callers:
  - [path:line] — [呼び出し元]
- downstream effects:
  - [path:line] — [影響先]
- tests:
  - [path] — [既存テスト / none]

Terminology:
- confirmed:
  - [用語]: [コード / docs から確認できる意味]
- possible mismatch:
  - [ユーザー語] ↔ [コード上の語 path:line] — [確認理由]

Evidence:
- [path:line / command output / commit] — [根拠]

Unknowns:
- [コード/docsだけでは分からないこと]

Suriawase:
- needed: yes/no
- reason: [必要/不要の理由]
- first question: [needed: yes の場合のみ、一問]
- recommended answer: [推奨案 + 1 行根拠]
- docs update:
  - CONTEXT.md: [追記候補 / none]
  - ADR: [候補 / none]

Next:
- handoff: kouchiku / shiken / none
- brief: [渡す要約]
```

## すり合わせモード

探索で見つけた曖昧さを、実装前に必要な分だけ詰める。質問は一問ずつ。各質問には推奨案と理由を添える。

**自動発火条件**

- ユーザーの用語とコード上の用語がズレている
- 同じ概念を複数名で呼んでいる
- `CONTEXT.md` に定義がない重要用語がある
- 要求の対象範囲が複数に解釈できる
- 後から変えるコストが高い設計分岐がある
- issue / 要望に DoD がない
- 影響範囲が広いのに成功条件が曖昧
- ADR に残すべき重い設計判断の候補がある

**自動発火しない条件**

- コードと要求が明確に一致している
- 変更が小さく、対象ファイルも狭い
- 用語ズレが単なる日本語/英語の表記違い
- 既存テストや実装から期待挙動が明確
- ユーザーが「調査だけ」「実装はしない」と明示している

**質問フォーマット**

```
すり合わせが必要です。
確認したいことは1つです。

Question: [質問]
Recommended: [推奨案]
Reason: [1-2 行根拠。Evidence があれば path:line を含める]

この回答で決まる docs:
- CONTEXT.md: [追記候補 / none]
- ADR: [必要なら候補 / none]
```

回答を得たら、解決済み事項を `Terminology.confirmed` または `Unknowns` から取り除いた handoff brief に反映する。`CONTEXT.md` / ADR の実ファイル更新は、ユーザーが明示的に求めた場合だけ行う。

## Handoff Policy

`tansaku` は探索結果を次の skill に渡す。判断や実装を自分で引き受けない。

| 条件 | handoff 先 | 理由 |
| --- | --- | --- |
| 設計判断 / 計画化 / 実装方針が必要 | `kouchiku` | controller が判断を保持する |
| 既に 1 vertical behavior slice が明確で TDD に進める | `shiken` | テスト discipline は shiken が持つ |
| 調査だけで完了 | `none` | 実装・判断に進まない |

handoff 時は以下の block を必ず出す。

```
handoff: [skill]
reason: [なぜ今渡すか]
context: [探索対象 / 仕様 / 用語 / 未決事項]
map:
  - [entry / core / caller / downstream]
terminology:
  - [confirmed / possible mismatch]
unknowns:
  - [未確認事項]
evidence:
  - [file:line / command output / logs]
expected return:
  - [戻してほしい成果物]
```

## 停止条件

- 実装コードを書かない
- 採用案を確定しない
- review finding として severity を付けない
- TDD slice を勝手に増やさない
- PR 本文を書かない
- 破壊的な自動実行 (`rm -rf`, `git reset --hard`, force push 等) は明示確認なしに走らせない
- 実装前に決めないと手戻りが大きい不明点がある場合は、すり合わせ mode で一問だけ確認する

## 完了記録

```
mode:              探索 / すり合わせ / handoff
worktree:          in-worktree / normal-repo
output type:       map / question / handoff-brief
suriawase:         needed / not-needed / completed
handoff target:    kouchiku / shiken / none
evidence:
  - [path:line / command output / logs]
```
