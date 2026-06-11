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

情報取得・構造把握・用語整理・未決事項の確認を扱う。判断と実装はしない — 設計判断 / 計画化 / 実装は `kouchiku`、TDD は `shiken`、レビューは `sadoku`、提出は `teishutsu` に渡す。探索で事実を集め、実装前に決めないと手戻りが大きい曖昧さが見つかった時だけ、すり合わせ mode に自動遷移する。

<!-- hikizan:contract:start -->
## 共通契約

全 hikizan skill 共通。ここを変えたら `scripts/check-consistency.sh` が 5 skill の同一性を検査する。

- **tier**: 環境が宣言する自律度に従う。`hikizan-tier: standard` (floors=hooks のある環境: Claude Code の /plugin、floors 導入済み Cursor 等) は invariant を満たす限り「既定手順」を圧縮してよい。`guided` (既定 / floors 未導入) は「既定手順」を遵守する。未宣言なら `guided` 扱い。
- **risk dial**: 可逆で推測可能 → 自律で進める / 計画の分岐点 → 確認を取る / 不可逆・破壊的 → 止めてユーザ確認。tier に関わらず不可逆操作は止める。
- **必須 (invariant)**: 「必須」と記す項目は全 tier で省略不可 — 検証ログは command 出力を引用し自己申告にしない / PII・Secrets scan / 命名規約 / 破壊的操作の明示確認。
- **既定手順 (procedure)**: 「既定手順」と記す節は guided では遵守、standard では invariant を満たす限り圧縮・省略してよい。
- **handoff**: skill 間遷移は次の block を出す。
  ```
  handoff: [skill]
  reason: [なぜ今渡すか]
  context: [症状 / 仕様 / 設計判断]
  evidence:
    - [file:line / command output / logs]
  expected return:
    - [戻してほしい成果物]
  ```
- **命名**: PR / branch / step は issue 名 / 機能名 / branch 名で呼ぶ。独自連番 (PR-1 等) 不可、重複時のみ -v2, -v3。
<!-- hikizan:contract:end -->

## worktree 検出 (必須)

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較。異なれば worktree 内 — branch 名を完了記録の `worktree` 行に記録する。worktree の作成・削除はしない。

## モード (router)

| モード | 入力トリガー | 状態トリガー | 動作 |
| --- | --- | --- | --- |
| 探索 | `探索して` / `全体像を掴んで` / `この辺り見て` / `影響範囲を調べて` / `zoom-out` | 未知領域 / 影響範囲不明 / kouchiku 前の文脈不足 | コード・docs・履歴から Map / Terminology / Unknowns を作る |
| すり合わせ | `すり合わせ` / `仕様を詰めたい` / `用語を整理したい` | 探索中に実装前確認が必要な曖昧さを検出 | 一問ずつ確認し推奨案と docs 更新候補を出す |

軽微な不明点は `Unknowns` に残し、作業を止めすぎない。すり合わせの自動発火条件と質問フォーマットは `references/suriawase.md`。

## 必須 (invariant)

- 実装コードを書かない / 採用案を確定しない / review finding に severity を付けない / TDD slice を勝手に増やさない / PR 本文を書かない
- 事実と推測を分ける。`Evidence` は file:line / command output / commit など受け手が再確認できるものにする
- シンボル探索 (関数 / クラス / 変数の定義・参照) は LSP 優先、テキスト探索 (TODO / FIXME / 設定 / コメント文字列) は grep。LSP 未設定なら grep にフォールバック
- 実装前に決めないと手戻りが大きい不明点があれば、すり合わせ mode で一問だけ確認する

## 既定手順 (procedure)

**読む順序**: ① 入口文書 (`README.md` / `AGENTS.md` / `docs/` / `CONTEXT.md` / `docs/adr/`) → ② ユーザー指定の file / dir / issue の語 → ③ 関連シンボルの定義・参照・呼び出し元 → ④ 既存テスト / 検証コマンド → ⑤ 周辺履歴 (recent commits / 新規 file / TODO・FIXME)。

```bash
git log --oneline -20
git submodule foreach 'git log --oneline -5' 2>/dev/null
grep -rn "TODO\|FIXME" <関連 dir> | head -20
git log --diff-filter=A --name-only -10 | head -30
```

## 出力契約 (探索)

```
Explored: [対象領域 / 依頼内容]
worktree: in-worktree / normal-repo

Map:
- entry points / core modules / upstream callers / downstream effects / tests
  - [path:line] — [役割]
Terminology:
- confirmed: [用語: コード/docs から確認できる意味]
- possible mismatch: [ユーザー語 ↔ コード上の語 path:line — 確認理由]
Evidence:
- [path:line / command output / commit] — [根拠]
Unknowns:
- [コード/docs だけでは分からないこと]
Suriawase:
- needed: yes/no — reason / (yes なら) first question + recommended answer + docs 更新候補
Next:
- handoff: kouchiku / shiken / none — brief: [渡す要約]
```

## handoff Policy (必須)

| 条件 | 先 | 理由 |
| --- | --- | --- |
| 設計判断 / 計画化 / 実装方針が必要 | `kouchiku` | controller が判断を保持 |
| 1 vertical behavior slice が明確で TDD に進める | `shiken` | test discipline は shiken |
| 調査だけで完了 | `none` | 実装・判断に進まない |

handoff 時は共通契約の block に加え `map / terminology / unknowns` を含める。

## 完了記録 (必須)

```
mode:           探索 / すり合わせ / handoff
worktree:       in-worktree / normal-repo
output type:    map / question / handoff-brief
suriawase:      needed / not-needed / completed
handoff target: kouchiku / shiken / none
evidence:
  - [path:line / command output / logs]
```

## references/

- `suriawase.md` — すり合わせの自動発火条件・質問フォーマット・docs 更新の扱い
