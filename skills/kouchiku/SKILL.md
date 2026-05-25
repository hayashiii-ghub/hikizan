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

設計判断、評価、計画策定、承認済み計画の実行を扱う。原因未確定の不具合や予期しない test failure は、計画実行内の診断分岐で root cause を確定する。情報取得 / 文脈整理 / 用語すり合わせ、TDD / レビュー / 提出の discipline は内包せず、必要な局面で `tansaku` / `shiken` / `sadoku` / `teishutsu` に渡す。

## Step 0: worktree 検出

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較する。異なれば worktree 内 — branch 名とともに表示し、完了記録の `worktree` 行に記録する。

## Phase 0: 必要に応じて tansaku

通常検討 / 計画実行の前提情報が足りない場合は、判断に入る前に `tansaku` へ handoff する。`kouchiku` 自身は広域探索を再実行しない。`tansaku` return の `Map` / `Terminology` / `Unknowns` / `Evidence` を前提として、設計判断と計画化に集中する。

`tansaku` に渡す条件:

- 未知の code area / module boundary に触れる
- 影響範囲、呼び出し元、依存先が不明
- ユーザーの用語とコード上の用語がズレている疑いがある
- `CONTEXT.md` / ADR / docs の確認が必要
- issue / 要望の DoD が曖昧
- 実装前に決めないと手戻りが大きい未決事項がある

`tansaku` を呼ばずに進めてよい条件:

- 変更が小さく、対象ファイルと期待挙動が明確
- 既存テストや実装から仕様が十分に読める
- ユーザーが設計判断だけを求めており、追加探索のコストが判断価値を上回る

handoff 例:

```
handoff: tansaku
reason: 設計判断前に影響範囲と用語を整理する必要がある
context: [要望 / issue / 対象 file]
evidence:
  - [既に分かっている file:line / docs]
expected return:
  - Map / Terminology / Unknowns / Evidence
  - すり合わせが必要なら first question + recommended answer
```

## モード切替


| モード  | 入力トリガー                                | 状態トリガー           | 動作                                          |
| ---- | ------------------------------------- | ---------------- | ------------------------------------------- |
| 軽量検討 | `どうやって直す` / `やり方どっち`                  | scope が 3 ファイル未満 | 推奨 1 案 (file:line) + brute force 案 + 1 risk |
| 通常検討 | `設計どうする` / `方針決めたい` / `アーキテクチャ判断`     | 新機能着手前           | 推奨案 + 1 代替 (近接時のみ) + 前提崩し + 前提リスク検証 + 計画化 |
| 評価   | `やる価値ある` / `採用すべきか` / `そもそも` / `やめる?` | なし               | Kill / Keep / Pivot 判定 + 3 理由               |
| 計画実行 | `計画実行` / `進めて` / `着手` / `実装開始`        | 通常検討の出力が承認直後     | 計画を実行、各 step で検証、完了報告まで                     |


通常検討 → 計画実行は同じ skill 内で連続して実行する。原因未確定なら計画実行内の診断分岐で root cause を確定し、TDD 必要層なら `shiken`、実装完了後は `sadoku` に handoff block で渡す。

## Handoff Policy

kouchiku は controller として次の skill を選ぶが、専門 skill の責務を内包しない。


| 条件                                                                                 | handoff 先                                 | 理由                                             |
| ---------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------- |
| 原因未確定の不具合 / 予期しない test failure / 再現不明の挙動                                           | `kouchiku` 診断分岐                         | root cause を確定してから設計判断する                       |
| 純ロジック / API / ビジネスルール / bugfix 実装                                                  | `shiken`                                  | 1 vertical behavior slice ごとに RED → GREEN → PRUNE の discipline を守る |
| 実装完了後の diff review                                                                 | `sadoku`                                  | 実装者視点から離れて diff を見る                            |
| 整理 (重複削除 / 命名統一 / 不要な抽象化除去 / dead code / efficiency)                               | `sadoku` simplify findings → kouchiku で実装 | 発見は sadoku、実装は controller が responsibility を持つ |
| PR 本文ドラフト / PR 提出 (remote 確認 / submodule / parent commit / cwd-aware gh pr create) | `teishutsu`                               | hook と二段構成、submission 工程の未確認項目を skill で先に検出 |
| 情報取得 / 影響範囲把握 / 用語すり合わせ / docs・ADR 確認                                             | `tansaku`                                | 判断前の文脈整理を分離し、kouchiku は設計判断に集中する |
| 設計判断 / scope 整理 / 計画分解 / 複数案評価                                                     | `kouchiku`                                | controller が判断を保持する                            |


handoff 時は以下の block を必ず出す。`evidence` は file:line / command output / logs など、受け手が再確認できるものにする。

```
handoff: [skill]
reason: [なぜ今渡すか]
context: [症状 / 仕様 / 設計判断]
evidence:
  - [file:line / command output / logs]
expected return:
  - [戻してほしい成果物]
```

## 軽量検討モード

scope が 3 ファイル未満の修正方法選択。出力は短く:

```
推奨:    [案、file:line で示す、N/10 + 1 行根拠]
brute:   [雑にやるならこれ、N/10 + 1 行根拠]
risk:    [採用時の最大の懸念 1 つ]
```

3 案以上は提示しない (選択肢過多を避ける)。明確な case は推奨 1 案で十分。brute は省略してもよい (引き算原則)。

## 通常検討モード

新機能 / アーキテクチャ判断。

**思考の手順**

1. **問題定義**: 何を解決するか、何を解決しないか (out-of-scope) を分ける
2. **推奨案を 1 つ**: file:line / 関連 module / 影響範囲を具体的に
3. **代替案は近接時のみ 1 つ**: 推奨と近い (= 議論する価値がある) ものだけ。遠い案は出さない
4. **前提崩し**: 「この設計が前提としている事実」を 3-5 個列挙し、それぞれが崩れたらどうなるかを評価
5. **前提リスク検証**: 「この案を採用した 6 ヶ月後に問題化しうるシナリオ」を 1 つ書く
6. **計画化**: 計画実行モードに渡せる形 (step / owner skill / file / 検証コマンド) で出力

**出力形式**

```
Building:        [何を作る、1 段落]
Not building:    [out-of-scope、1-3 項目]
Approach:        [選んだ案、推奨度 N/10 + 1 行根拠]
Alternatives:    [代替案がある場合のみ、各案に推奨度 N/10 + 1 行根拠]
                 ※ 明確なら 1 案でよい、迷うときのみ代替案 1 つ
Structure:       [任意] 構造変更 (module 境界 / 依存 / data flow) を伴う場合のみ
                 before/after を mermaid 1 枚で。線形手順だけなら省略
Key decisions:   3-5 項目 (それぞれ「ほかの選択肢を採らなかった理由」を 1 行)
Interface sketch: [任意] 最も load-bearing な interface 1 点を signature / data 形で
                 (実在 symbol を file:line 付きで参照、~5-8 行、logic 本体なし)
Premises:        この設計が依存している事実 3-5 個 (各項目に ✓ file:line で確認済 / ⚠ 未検証 を注記)
Worst case:      6 ヶ月後に問題化しうるシナリオ
Unknowns:        defer 理由 + 担当明記の項目のみ
Plan steps:      実装単位 (owner skill / file / 検証コマンド。TDD 必要層は next slice / candidate follow-up slices を分ける)
Minimal Approach: 上記 plan を要求から直接読める規模と対比、最小版を併記または "minimal already" を明記
```

**Minimal Approach の判定**:

通常検討モードでは `Minimal Approach:` を書く前に `references/minimal-approach.md` を読む。

- issue 文の動詞 (「追加する」「換装する」等) と名詞句を抽出し、要求から直接読める規模 (ファイル数 / 行数 / step 数) を概算する
- plan が要求から直接読める規模の 2 倍以上 → 引き算した最小版を併記し、defer した項目を明示
- 2 倍未満 → "minimal already" と明記

**Structure 図 / Interface sketch の指針** (どちらも任意):

- **Structure 図**: 構造変更 (module 境界 / 依存 / data flow) を伴うときだけ mermaid。線形手順は箇条書きで足りる
- **Interface sketch**: 1 plan に 1 つ、最も load-bearing な interface 境界のみ。approach 選定後に書く。実在 symbol を `file:line` で参照 (grounded、invent 不可)。logic 本体は書かない (要るなら実装 → `Unknowns` に defer)
- sketch は「signature を綺麗に書けない = 設計未確定」を plan 時点で炙り出す forcing function。何も surface しなければ documentation 止まり

## 評価モード

Kill / Keep / Pivot のいずれか + 3 理由を即座に出す。判断軸は **ユーザの制約** (時間 / 人員 / 顧客約束 / 競合状況)。技術的な好みだけで決めない。

```
Verdict:    Kill / Keep / Pivot
Reasons:    1. [user constraint に紐づく理由]
            2. ...
            3. ...
If pivot:   [何に方向転換するか、1 段落]
```

3 択以外は出さない (「保留」は判断回避)。

## 計画実行モード

承認済みの計画を実行する。前提: 通常検討モードの出力に推奨案 / Key decisions / Plan steps が含まれている。

**手順**

1. 計画を再読し、不明点があれば確認を投げる
2. step ごとに inline で実装 (subagent には委譲しない。原因未確定なら診断分岐、TDD 必要層なら `shiken` に handoff)
3. 各 step 完了後に検証 (test / lint / type-check / 手動確認)
4. scope 外の発見は実装せず「実装中に分かったこと」に記録 (後で `teishutsu` の PR 本文ドラフトで参照)
5. 完了報告を出力 → `sadoku` に PR レビュー用 handoff block を渡す

**TDD 必要層を踏むときの分岐**

純ロジック / API / バグ修正 などの必須レイヤーに触れる場合は、計画実行を一時停止して `shiken` (TDD) のサイクルに入る。`kouchiku` は実装計画を vertical behavior slice に分解し、`shiken` には次に閉じる 1 slice だけを渡す。GREEN → PRUNE を終えてから次の step に戻る。

- Plan steps には候補 slice を列挙してよいが、確定扱いは次に実行する 1 slice のみ
- `shiken` return の `coverage gap` を読んで、gap を受け入れる / 次 slice にする / test level を変える、の判断を `kouchiku` が行う
- `shiken` に後続 slice の設計や追加実装を任せない

**診断分岐**

原因未確定の不具合 / 予期しない test failure / 再現不明の挙動に当たったら、実装変更を止めて root cause を確定する。
調査技法は `references/diagnosis-techniques.md` に置く。

- root cause を 1 文で言語化できるまで実装を変更しない (`I believe the root cause is [X] because [evidence].`)
- 症状をそのまま列挙する: error message, stack trace, 再現手順, 期待値, 実際の値
- hypothesis を 1 文にし、`references/diagnosis-techniques.md` を読んで instrument を 1 つだけ走らせる
- confirm → fix / `shiken` へ。discard → hypothesis を再構築
- 同じ症状が修正後も残る場合は停止し、hypothesis を再構築する
- 3 回失敗したら `hypothesis attempts` / `current best guess` / `remaining unknowns` / `recommended next step` を出して user の proceed 判断を求める
- fix が 5+ ファイルに touch するなら scope を確認する (= 別 bug の可能性)
- fix 後は同 input に対する before / after の挙動 diff を完了記録にそのまま引用する
- regression guard が必要なら `shiken` に渡す。root cause と再現条件を固定し、TDD の実装 discipline は `shiken` に委譲する

**handoff 例**

```
handoff: shiken
reason: API の挙動に触れる実装のため
context: [仕様 / edge case / non-goals]
vertical slice:
  entry: [user action / API call / public function]
  behavior: [観測したい振る舞い]
  observable output: [UI / response / return value / state change / persisted data]
  excluded layers: [この cycle で通さない層]
evidence:
  - [関連 file:line]
expected return:
  - RED log
  - GREEN log
  - PRUNE result
  - test level / coverage gap / prune witness
  - verification command
```

## 停止条件

- 破壊的な自動実行 (`rm -rf`, `git reset --hard`, force push 等) は明示確認なしに走らせない
- 計画にない変更を実施しない (scope 外の発見は記録のみ、実装しない)
- 検証コマンドが失敗したら次の step に進まない。診断分岐で root cause を追跡
- 計画に無い 5+ ファイル touch が発生したら停止し、scope を再確認

## Hard Rules

- 計画実行モード以外では実装コードを書かない。設計を一意に固定する説明用 snippet (signature / data 形、~5-8 行・logic 本体なし) は可
- 3 案以上は出さない (paralysis 防止)
- 前提崩し / 前提リスク検証を埋めずに通常検討モードの出力を返さない
- 評価モードは user 制約を根拠にする (技術的な好みだけで Kill/Keep を決めない)
- PR / branch / step を独自連番 (PR-1 等) で呼ばない。issue 名 / 機能名 / branch 名で呼ぶ。重複時のみ -v2, -v3 ... のサフィックスを使う

## 承認後の文言

通常検討モードの出力が承認されたら、以下の文言で計画実行モードに移行することを告げる:

```
Plan approved. 次に進む場合は番号で返してください。
1. 実装する
2. 計画を直す
3. 中止する
実装完了後は /sadoku に渡してレビューします。
```

## subagent

本 skill は判断を扱うため、対象情報を集める段階 (例: 候補 library 3 つの最新動向を比較する Web 横断調査) でのみ subagent を 1 つ起動する。判断そのものは inline で controller が行う。計画実行モードは inline 実行を原則とし、機械的な fan-out のみ subagent を検討する。

## 完了記録

検討 / 評価モードの出力は環境変更を伴わないため検証ログ不要。計画実行モードの出力は環境変更を伴うため検証ログ必須。

```
mode:              軽量検討 / 通常検討 / 評価 / 計画実行
worktree:          in-worktree / normal-repo
output type:       plan / verdict / evaluation / execution-result
handoff target:    shiken / sadoku / teishutsu / none

# 計画実行モードのみ
steps done:        N (of M planned)
diagnosis:         [root cause / before-after diff / none]
verification:      [command] -> pass / fail
                     検証ログ: [出力末尾 3-5 行、失敗時は full error]
scope drift:       on target / drift: [何を別 issue に切り出したか]
```

## references/

- `minimal-approach.md` — 引き算プロトコル本体 (`Minimal Approach:` セクションと推奨度 N/10 の付け方)
- `diagnosis-techniques.md` — 診断分岐で hypothesis を confirm / discard する instrument 集
