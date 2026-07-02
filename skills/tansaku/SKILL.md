---
name: tansaku
description: "Use this skill when the user wants to understand an unfamiliar code area, gather context before design, map impact scope, inspect related files, or clarify domain terminology before implementation — including phrasings 探索して, 全体像を掴んで, この辺り見て, 影響範囲を調べて, 関連ファイルを洗って, zoom-out, 用語を整理して. Activate before sekkei when the request depends on unknown code structure, domain terminology, or docs/ADR context."
license: MIT
when_to_use: "探索, 全体像把握, 影響範囲調査, 用語整理"
---

# tansaku (探索)

```
🌲 Using /tansaku for [purpose taken from trigger context].
```

調べて報告する skill。実装と設計判断はしない。設計と計画は `sekkei`、実行は `jikkou`、テスト先行の実装は `shiken`、レビューは `sadoku`、提出は `teishutsu` に渡す。

<!-- hikizan:contract:start -->
## 共通ルール

core 7 skill (init を除く全 skill) 共通。`scripts/check-consistency.sh` が 7 skill で同一であることを検査する。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は docs/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は docs/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 手順

1. 入口文書を読む: `README.md` / `AGENTS.md` / `docs/` / ADR
2. 探索の広さを見積もる。独立に読める領域 / sub-question が 3 つ以上に割れるなら、以降の深い読み (シンボル / テスト / 履歴 / 指定領域) を read-only な探索 subagent に fan out する (最大 3 並列、渡し方と裏取りは `references/fanout.md`)。1 本の線形トレースなら inline で読む。合成 (用語確定 / CONTEXT.md / 報告) は controller が持つ
3. ユーザが指定した file / dir / issue の語が出る場所を読む
4. 関連シンボルの定義・参照・呼び出し元を辿る (関数や変数は LSP、TODO やコメント等の文字列は grep。LSP が無ければ全部 grep)
5. 既存テストと検証コマンドを確認する
6. 履歴を見る:
   ```bash
   git log --oneline -20
   grep -rn "TODO\|FIXME" <関連 dir> | head -20
   ```
7. 用語のズレ (ユーザ用語 vs コード用語 / 同じ概念を複数名で呼ぶ / 重要用語の定義が無い) を見つけたら、事実で解消できるものは Terminology に確定する。事実で決まらない用語だけ一問ずつ user に確認する (推奨案を 1 行添える)。ただし単なる日本語/英語の表記違いは確認しない
8. 確定した 用語 / 不変条件 / 制約 / 受容済みリスク は、報告に載せるだけでなく CONTEXT.md への **diff 提案**として出す (提案 by default、適用は user 承認、silent に書き換えない)。既存のドメイン doc (`CLAUDE.md` / `AGENTS.md` / `docs/`) があればそこへ追記、無ければ root に `CONTEXT.md` を作る (1 repo 1 正本)。設計の決定 (なぜ選んだか) は書かない (それは ADR / `sekkei`)。詳細は `references/context-doc.md`
9. 下の「報告」を埋めて返す。確認できた事実には file:line かコマンド出力を付ける。確認できないことは推測で埋めず Unknowns に書く。構造がグラフ的 (依存 / 制御フロー / やり取り / データモデル) なら、文章でなく mermaid を 1 枚添える (`references/mermaid-views.md`)
10. 実装前に決めるべき設計分岐 / DoD / 受容条件の曖昧さは、自分で詰めず `sekkei` に渡す (tansaku は設計判断をしない)。小さな不明点は Unknowns に残して止まらない

## やってはいけないこと

- 実装コードを書く / 設計案を確定する / PR 本文を書く
- 設計分岐・DoD・受容条件を自分で詰める (`sekkei` に渡す)
- CONTEXT.md に設計の決定・理由を書く (それは ADR / `sekkei`) / user 承認なしに CONTEXT.md を書き換える
- 事実と推測を混ぜる (evidence の無い行は Unknowns へ)
- 質問を一度に複数並べる
- 探索 subagent に用語確定 / CONTEXT.md 書き込み / 設計判断 / handoff を任せる (controller 所有、詳細は `references/fanout.md`)

## 報告 (穴埋め)

最初に結論を 1 文。続けて調査結果をまとめる。確認できた事実には file:line かコマンド出力を添える。

[1 文: 何を調べて何が分かったか、次に何へ渡すか]

- Explored: [何を調べたか]
- Map:
  - [path:line]、[役割]
- Terminology:
  - [用語] = [コード/docs 上の意味] ([path:line])
- CONTEXT.md: [追記 / 新規の diff 提案 (承認待ち) / 変更なし]
- Unknowns:
  - [コードと docs だけでは分からないこと]
- next: [sekkei / shiken に渡す / 調査のみで完了]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `context-doc.md`：CONTEXT.md (ドメイン文脈の正本) の契約と書き込み手順 (提案 → 承認 → commit)
- `fanout.md`：広い探索を read-only subagent に分散する契約 (起動条件 / 渡す形 / 裏取り)
- `mermaid-views.md`：構造を mermaid で見せるときの図種別と最小例
