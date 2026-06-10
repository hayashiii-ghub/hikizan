---
name: kouchiku
description: "Use this skill when the user wants help deciding how to build something, evaluating whether to keep/kill/pivot an approach, drafting an implementation plan, or executing an approved plan — including phrasings 設計どうする, 方針決めたい, どうやって直す, やり方どっち, やる価値ある, 採用すべきか, kill か keep か, 計画実行, 進めて, 着手. Activate when discussing technical trade-offs, or when the user just got approval and wants implementation — even without explicit 'design' or 'plan' wording."
license: MIT
when_to_use: "設計判断, 方針決め, design decision, kill or keep, 計画実行"
---

# kouchiku (構築)

```
🌲 Using /kouchiku for [purpose taken from trigger context].
```

設計判断・評価・計画策定・承認済み計画の実行を担う controller。原因未確定の不具合は計画実行内の診断分岐で root cause を確定する。情報取得は `tansaku`、TDD は `shiken`、レビューは `sadoku`、提出は `teishutsu` に handoff する (責務は内包しない)。

<!-- hikizan:contract:start -->
## 共通契約

全 hikizan skill 共通。ここを変えたら `scripts/check-consistency.sh` が 5 skill の同一性を検査する。

- **tier**: 環境が宣言する自律度に従う。`hikizan-tier: standard` (Claude Code = hooks の floors あり) は invariant を満たす限り「既定手順」を圧縮してよい。`guided` (既定 / Cursor 等 floors なし) は「既定手順」を遵守する。未宣言なら `guided` 扱い。
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

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較。異なれば worktree 内 — branch 名を完了記録の `worktree` 行に記録する。

## モード (router)

| モード | 入力トリガー | 状態トリガー | 出力 | 手順 |
| --- | --- | --- | --- | --- |
| 軽量検討 | `どうやって直す` / `やり方どっち` | scope < 3 ファイル | 推奨案 + brute + risk | 本文下記 |
| 通常検討 | `設計どうする` / `方針決めたい` / `アーキテクチャ判断` | 新機能着手前 | Building…Plan steps | `references/design.md` |
| 評価 | `やる価値ある` / `採用すべきか` / `やめる?` | — | Verdict + 3 理由 | 本文下記 |
| 計画実行 | `計画実行` / `進めて` / `着手` | 通常検討の承認直後 | execution-result | `references/execution.md` |

通常検討 → 計画実行は連続実行。前提情報が足りなければ判断前に `tansaku` へ handoff し、自分で広域探索を再実行しない。

## handoff 先 (必須: 専門 skill の責務を内包しない)

| 条件 | 先 |
| --- | --- |
| 原因未確定の不具合 / 予期しない test failure | `kouchiku` 診断分岐 |
| 純ロジック / API / ビジネスルール / bugfix 実装 | `shiken` (1 vertical slice ごと) |
| 実装完了後の diff review / 整理観点 | `sadoku` (整理の実装は kouchiku に戻す) |
| PR 本文ドラフト / PR 提出 | `teishutsu` |
| 情報取得 / 影響範囲把握 / 用語すり合わせ | `tansaku` |
| 設計判断 / scope 整理 / 計画分解 | `kouchiku` |

## 必須 (invariant)

- 計画実行モード以外で実装コードを書かない (設計を一意に固定する signature / data 形 snippet ~5-8 行・logic 本体なしは可)
- 通常検討は前提崩し / 前提リスク検証を埋めずに出力を返さない
- 評価は user 制約 (時間 / 人員 / 顧客約束 / 競合) を根拠にする。技術的好みだけで Kill/Keep しない。「保留」は出さない
- 3 案以上は出さない (paralysis 防止)
- 計画実行: 検証コマンドが失敗したら次 step に進まない (診断分岐で root cause)。計画に無い 5+ ファイル touch で停止し scope 再確認。scope 外の発見は記録のみで実装しない
- 計画実行 / 診断の出力は検証ログ必須 (command 出力を引用、自己申告不可)。検討 / 評価は環境変更なしのため検証ログ不要

## 出力契約 (既定手順)

**軽量検討** — 3 案以上禁止。明確なら推奨 1 案で十分。

```
推奨:  [案、file:line で示す、N/10 + 1 行根拠]
brute: [雑にやるなら、N/10 + 1 行根拠 / 省略可]
risk:  [採用時の最大の懸念 1 つ]
```

**通常検討** — 詳細手順と Minimal Approach 判定は `references/design.md`。

```
Building / Not building / Approach (N/10) / Alternatives (近接時のみ) /
Structure (構造変更時のみ mermaid) / Key decisions (3-5, 各「不採用理由」1行) /
Interface sketch (任意, 最 load-bearing な 1 点, 実在 symbol を file:line) /
Premises (3-5, 各 ✓file:line / ⚠未検証) / Worst case / Unknowns / Plan steps /
Minimal Approach (要求規模と対比、最小版併記 or "minimal already")
```

**評価**

```
Verdict: Kill / Keep / Pivot
Reasons: 1-3 (user 制約に紐づく)
If pivot: [方向転換先、1 段落]
```

**計画実行** — step ごとに inline 実装 (subagent 委譲しない)、各 step で検証、TDD 必要層は `shiken` に 1 slice、原因未確定は診断分岐。詳細は `references/execution.md`。

## 診断分岐 (必須の discipline)

原因未確定の不具合に当たったら実装変更を止め root cause を 1 文で固定する (`I believe the root cause is [X] because [evidence].`)。symptom 列挙 → hypothesis 1 文 → `references/diagnosis-techniques.md` の instrument を 1 つ → confirm/discard。3 回失敗で `hypothesis attempts / current best guess / remaining unknowns / recommended next step` を出して user 判断を仰ぐ。regression guard は `shiken` に渡す。

## 承認後の文言

通常検討の出力が承認されたら次を告げる:

```
Plan approved. 次に進む場合は番号で返してください。
1. 実装する
2. 計画を直す
3. 中止する
実装完了後は /sadoku に渡してレビューします。
```

## subagent

判断は inline で controller が行う。対象情報を集める段階で gate (a) 重い情報取得 (例: library 3 つの最新動向の Web 横断) に該当する時のみ subagent を 1 つ起動。計画実行は inline 原則 (機械的 fan-out = gate (c) のみ subagent 検討)。

## 完了記録 (必須)

```
mode / worktree / output type: plan / verdict / evaluation / execution-result
handoff target: shiken / sadoku / teishutsu / tansaku / none

# 計画実行 / 診断のみ (検証ログ必須)
steps done:    N (of M)
diagnosis:     [root cause 1 文 + 同 input の before/after diff / none]
verification:  [command] -> pass / fail
                 検証ログ: [出力末尾 3-5 行、失敗時は full error]
scope drift:   on target / drift: [別 issue に切り出したもの]
```

## references/

- `design.md` — 通常検討の思考手順と出力テンプレ詳細
- `execution.md` — 計画実行の手順 (step 実装 / 検証 / TDD・診断分岐 / 完了報告)
- `diagnosis-techniques.md` — 診断 instrument 集
- `minimal-approach.md` — 引き算プロトコルと推奨度 N/10 の付け方
