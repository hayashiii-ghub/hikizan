---
name: shiken
description: "Use this skill when implementing behavior or fixing bugs in pure logic, business rules, API behavior, or build/CI logic — anywhere a regression would be costly. The skill enforces TDD discipline: failing test first, witness fail, implement minimally, PRUNE after green. Phrasings include TDDで, テストから書いて, テスト先行. Activate when fixing a bug that needs a regression guard or adding logic to untested code — even without explicit 'TDD' wording."
license: MIT
when_to_use: "TDD, テスト先行, テストから書く"
---

# shiken (試験)

```
🌲 Using /shiken for [purpose taken from trigger context].
```

> **テストが先。fail を目視するまで実装に手を付けない。「あとで書く」「手で確認した」は理由にならない。**

TDD discipline。失敗するテストを先に書き、fail を**目視**してから実装する。GREEN 後に PRUNE で test を最小化する。1 cycle は原則 1 vertical behavior slice とし、slice の分解は `kouchiku` が担う。

## Step 0: worktree 検出

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較する。異なれば worktree 内 — branch 名とともに表示し、完了記録の `worktree` 行に記録する。

一時的な test 変更が大きい場合のみ、利用環境の標準機能で隔離 worktree / sandbox を使ってよい (作成・削除はその標準機能に従い、本 skill では行わない)。通常は現在の working tree で進める。隔離環境でも RED → GREEN → REFACTOR → PRUNE の順序と PRUNE 検証は省略しない。

## 起動トリガー

| 入力トリガー | 状態トリガー |
|---|---|
| `TDDで` / `テストから書いて` | 後段の「起動条件 (層分け)」表で判定 |

入力トリガーは明示 opt-in 用で、kouchiku 計画実行モードとの競合を避ける。直接起動時は user request から vertical slice を 1 文で明示し、scope 分割 / 設計判断 / root cause diagnosis / 複数 slice が必要なら RED に入らず `kouchiku` へ handoff する。

## Handoff Intake

`kouchiku` から呼ばれる時に期待する入力。足りない場合は推測で補完せず、停止条件として扱い、欠落項目を呼び出し元に問い合わせる。

```
handoff: shiken
reason: [TDD 必要層 (純ロジック / API / ビジネスルール) または regression guard]
spec: [testable な粒度に分解した仕様]
vertical slice:
  entry: [user action / API call / public function]
  behavior: [観測したい振る舞い]
  observable output: [UI / response / return value / state change / persisted data]
  excluded layers: [この cycle で通さない層]
edge cases: [この cycle に含める最小代表ケース / 後続 slice 候補]
non-goals: [この cycle で扱わない範囲]
root cause: [bugfix なら kouchiku 診断分岐の出力、新機能なら省略可]
test target:
  - [file / module]
  - [assert する behavior]
constraints:
  - [mock 呼び出し回数 assert 不可 等]
expected return:
  - RED log / GREEN log / PRUNE result / test level / coverage gap / prune witness / verification command
```

## Handoff Return

RED → GREEN → PRUNE の単位に落としきり、GREEN 後は実装判断を広げず、呼び出し元へ検証ログ付きで返す。

```
handoff return: kouchiku / sadoku
implemented behavior: [何を満たしたか]
vertical slice:
  entry: [...]
  behavior: [...]
  observable output: [...]
  excluded layers: [...]
test level:
  chosen: unit / integration / component / e2e
  reason: [なぜこの level で slice behavior を十分に保証できるか]
coverage gap:
  - [入口から通していない層 / 未検証の連携 / accepted gap or returned decision]
tests:
  - RED: [test runner output]
  - GREEN: [test runner output]
  - PRUNE: [observable output break -> fail -> restore -> pass]
prune witness: [どの observable output を壊して fail を確認したか]
files changed:
  - [path]
verification:
  - [command] -> pass / fail
```

## Hard Rules

- **書く側**: 失敗するテストを先に書き、本セッション内で fail を**目視**するまで実装コードを書かない
- **検証側**: PRUNE 後に残った各 test は、vertical slice の observable output を一時的に壊したときに必ず失敗することを目視確認する。失敗しない test = 何も検証していない (= 削除対象)
- `kouchiku` からの handoff に `vertical slice` が無い場合、RED に入らず呼び出し元へ差し戻す
- 直接起動で request を 1 つの vertical slice に言語化できない場合、scope を自分で分割せず `kouchiku` へ handoff する
- `coverage gap` を検出しても追加 slice を勝手に実装しない。gap を return に残し、次の slice 判断は `kouchiku` に戻す
- TDD RED-GREEN サイクルは **inline 必須**、subagent 委譲不可 (目視必須)
- スキップ判定 / スキップ時の記録 / セーフティ復帰は「スキップガード」section に従う
- PR / branch / step の命名は `kouchiku` Hard Rules に従う

## サイクル: RED → GREEN → REFACTOR → PRUNE

1 cycle は 1 vertical behavior slice を閉じる単位。既存 test 構造に合わせて unit / integration / component / e2e を選んでよいが、assert は private helper 形状ではなく slice の observable output に向ける。

| Phase | 動作 |
|---|---|
| RED | 失敗する test を 1 つ書く、test runner で fail を目視 |
| GREEN | test を pass させる最小実装、test runner で pass を目視 |
| REFACTOR | duplication 除去、命名改善、テストは green のまま |
| **PRUNE** | 各 test を slice behavior 基準で評価し、不要なものを削除 |

各 phase の遷移は test runner の出力 (最終 summary 行) で確認し、完了記録に検証ログとして引用する (「目視した」だけの自己申告は不可)。

### Slice 粒度

- 1 vertical slice は原則 1 kept test とする
- distinct な observable behavior を持つ edge case は別 slice として扱う
- 同じ cycle に含める edge case は、現在の behavior を代表する最小ケースに限る
- 1 slice に複数 test を残す場合は PRUNE result に理由を書く
- entry point から離れた test level を選ぶ場合は `reason` と `coverage gap` を return に残す

### PRUNE 評価基準

PRUNE に入る前に `references/testing-anti-patterns.md` を読む。

1. この test が落ちたら、vertical slice の observable output が壊れているか? → No なら**削除** (実装ロック疑い)
2. mock の存在・呼び出し回数を assert していないか? → Yes なら書き直し or 削除
3. 同じ assertion を別 setup で重複していないか? → 1 つに統合
4. 探索中に書いた scaffold か、spec を表現する test か? → scaffold なら削除
5. private helper 形状 / 内部分岐 / mock call count を壊した時だけ落ちていないか? → Yes なら observable output へ書き直し or 削除

PRUNE 後の test 数 = 残った仕様の数。

### PRUNE 検証手順 (各 test に対して必須)

推奨順:

1. 隔離 worktree で、vertical slice の observable output を一時的に壊して test failure を確認する
2. 同一 worktree なら、対象 file の現在状態を `/tmp` に保存し、observable output だけを最小変更で壊す
3. unrelated な dirty file がある場合、作業全体を `git stash` しない。scope を確認する

```bash
cp path/to/impl /tmp/hikizan-prune.impl
# vertical slice の observable output だけを一時的に壊す
<test runner> <test>    # → fail を確認 (= test が機能している)
cp /tmp/hikizan-prune.impl path/to/impl
<test runner> <test>    # → pass を再確認
```

fail しない test は「実装ロック」または「scaffold」のいずれかなので削除する。

## 起動条件 (TDD トリガー層分け)

| レイヤー | 例 | TDD 扱い |
|---|---|---|
| 純ロジック | utils / hooks (副作用なし) / store / reducer / validator / formatter | **必須** RED-GREEN-REFACTOR |
| ビジネスルール | 価格計算 / 権限判定 / 状態遷移 | **必須** |
| バグ修正 (どのレイヤーでも) | 再現テスト先行 | **必須** regression guard |
| インタラクション | click → state, form submit, a11y 要件 | **推奨** (Testing Library 等) |
| API 層 | fetch wrapper / query / mutation / data transform | **必須** (mock 境界明示) |
| 純スタイル / レイアウト | `.css` 単独, Tailwind class swap, spacing 調整 | **スキップ可** (理由必須) |
| アニメーション・文言・asset | i18n 語彙, icon, transition | **スキップ可** (理由必須) |
| 設定 / build / CI | package.json, tsconfig, workflow | **必須** 動作確認 (実行ログ) |

### 入口判定の材料

- 変更ファイル拡張子分布 (`.css` 単独 → スキップ寄り、`.tsx` のロジック block 触る → 必須)
- 既存 `*.test.{ts,tsx}` の有無 (あれば追加が natural)
- 変更意図 tag (bugfix / feature / refactor / style / chore)
- 純粋関数か副作用ありか

### スキップガード

- スキップ時は完了記録に 1 行必須:
  `tdd: skip — CSS-only layout adjustment, no logic touched`
- セーフティ復帰: ロジック行に 1 行でも触れたら必須扱いに戻す
- 「style 扱いの変更が他レイヤーに波及」も必須扱いに戻す
- PR 集計: `tdd: skip × N / enforced × M` を完了記録に出力

## 完了記録

機械検証可能項目は検証ログ (test runner 出力) をそのまま引用する。

```
worktree:          in-worktree / normal-repo
vertical slice:    [entry / behavior / observable output / excluded layers]
test level:        [unit / integration / component / e2e] + reason
coverage gap:      [accepted gap / returned decision / none]
cycle:             RED -> GREEN -> REFACTOR -> PRUNE 各 phase 完了確認
                     検証ログ (RED):     [test runner output 最終行、fail を含む]
                     検証ログ (GREEN):   [test runner output 最終行、pass]
                     検証ログ (PRUNE):   observable output break → fail → restore → pass の出力
prune witness:     [どの observable output を壊して fail を確認したか]
tests:             N kept (after PRUNE), M removed
tdd layer:         [必須 / 推奨 / スキップ可]
skip reason:       [スキップ時のみ、1 行]
```

## references/

- `testing-anti-patterns.md` — mock の存在 assert 不可、production class への test-only method 不可、部分 mock、snapshot 濫用、`.skip` 理由なし放置
