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

TDD discipline。失敗するテストを先に書き、fail を**目視**してから実装する。GREEN 後に PRUNE で test を最小化する。

## Step 0: worktree 検出

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
[ "$GIT_DIR" != "$GIT_COMMON" ] && echo "(worktree内: $(git branch --show-current))"
```

shiken は test を「書いて捨てる」局面が多いため、`wt` で隔離 worktree を切ると本流 branch を汚さない (詳細は後段「worktree 推奨ワークフロー」)。

## 起動トリガー

| 発話トリガー | 状態トリガー |
|---|---|
| `TDDで` / `テストから書いて` | 後段の「起動条件 (層分け)」表で判定 |

発話トリガーは明示 opt-in 用で、kouchiku 計画実行モードとの競合を防ぐ。

## Handoff Intake

`kouchiku` / `tansaku` から呼ばれる時に期待する入力。足りない場合は推測で補完せず、停止条件として扱い、欠落項目を呼び出し元に問い合わせる。

```
handoff: shiken
reason: [TDD 必要層 (純ロジック / API / ビジネスルール) または regression guard]
spec: [testable な粒度に分解した仕様]
edge cases: [想定する境界 / 例外]
non-goals: [この cycle で扱わない範囲]
root cause: [bugfix なら tansaku の出力、新機能なら省略可]
test target:
  - [file / module]
  - [assert する behavior]
constraints:
  - [mock 呼び出し回数 assert 禁止 等]
expected return:
  - RED log / GREEN log / PRUNE result / verification command
```

## Handoff Return

RED → GREEN → PRUNE の単位に落としきり、GREEN 後は実装判断を広げず、呼び出し元へ検証ログ付きで返す。

```
handoff return: kouchiku / tansaku / sadoku
implemented behavior: [何を満たしたか]
tests:
  - RED: [test runner output]
  - GREEN: [test runner output]
  - PRUNE: [temporary break -> fail -> restore -> pass]
files changed:
  - [path]
verification:
  - [command] -> pass / fail
```

## Hard Rules

- **書く側**: 失敗するテストを先に書き、本セッション内で fail を**目視**するまで実装コードを書かない
- **検証側**: PRUNE 後に残った各 test は、対応する実装を一時的に revert/破壊したときに必ず失敗することを目視確認する。失敗しない test = 何も検証していない (= 削除対象)
- TDD RED-GREEN サイクルは **inline 強制**、subagent 委譲禁止 (目視必須)
- スキップ時は完了記録に理由 1 行必須 (`tdd: skip — CSS-only layout adjustment, no logic touched`)
- ロジック行に 1 行でも触れたらスキップ判定から強制復帰
- PR / branch / step の命名は `kouchiku` Hard Rules に従う

## サイクル: RED → GREEN → REFACTOR → PRUNE

| Phase | 動作 |
|---|---|
| RED | 失敗する test を 1 つ書く、test runner で fail を目視 |
| GREEN | test を pass させる最小実装、test runner で pass を目視 |
| REFACTOR | duplication 除去、命名改善、テストは green のまま |
| **PRUNE** | 各 test を以下の基準で評価し、不要なものを削除 |

各 phase の遷移は test runner の出力 (最終 summary 行) で確認し、完了記録に検証ログとして引用する (「目視した」だけの自己申告は禁止)。

### PRUNE 評価基準

PRUNE に入る前に `references/testing-anti-patterns.md` を読む。

1. この test が落ちたら、本当の挙動破壊が起きているか? → No なら**削除** (実装ロック疑い)
2. mock の存在・呼び出し回数を assert していないか? → Yes なら書き直し or 削除
3. 同じ assertion を別 setup で重複していないか? → 1 つに統合
4. 探索中に書いた scaffold か、spec を表現する test か? → scaffold なら削除

PRUNE 後の test 数 = 残った仕様の数。

### PRUNE 検証手順 (各 test に対して必須)

推奨順:

1. 隔離 worktree で、対象実装だけを一時的に壊して test failure を確認する
2. 同一 worktree なら、対象 file の現在状態を `/tmp` に保存し、対象挙動だけを最小変更で壊す
3. unrelated な dirty file がある場合、作業全体を `git stash` しない。scope を確認する

```bash
cp path/to/impl /tmp/hikizan-prune.impl
# 対象挙動だけを一時的に壊す
<test runner> <test>    # → fail を確認 (= test が機能している)
cp /tmp/hikizan-prune.impl path/to/impl
<test runner> <test>    # → pass を再確認
```

fail しない test は「実装ロック」または「scaffold」のいずれかなので削除する。

## 起動条件 (TDD トリガー層分け)

| レイヤー | 例 | TDD 扱い |
|---|---|---|
| 純ロジック | utils / hooks (副作用なし) / store / reducer / validator / formatter | **強制** RED-GREEN-REFACTOR |
| ビジネスルール | 価格計算 / 権限判定 / 状態遷移 | **強制** |
| バグ修正 (どのレイヤーでも) | 再現テスト先行 | **強制** regression guard |
| インタラクション | click → state, form submit, a11y 要件 | **推奨** (Testing Library 等) |
| API 層 | fetch wrapper / query / mutation / data transform | **強制** (mock 境界明示) |
| 純スタイル / レイアウト | `.css` 単独, Tailwind class swap, spacing 調整 | **スキップ可** (理由必須) |
| アニメーション・文言・asset | i18n 語彙, icon, transition | **スキップ可** (理由必須) |
| 設定 / build / CI | package.json, tsconfig, workflow | **強制** 動作確認 (実行ログ) |

### 入口判定の材料

- 変更ファイル拡張子分布 (`.css` 単独 → スキップ寄り、`.tsx` のロジック block 触る → 強制)
- 既存 `*.test.{ts,tsx}` の有無 (あれば追加が natural)
- 変更意図 tag (bugfix / feature / refactor / style / chore)
- 純粋関数か副作用ありか

### スキップガード

- スキップ時は完了記録に 1 行必須:
  `tdd: skip — CSS-only layout adjustment, no logic touched`
- セーフティ復帰: ロジック行に 1 行でも触れたら強制復帰
- 「style 扱いの変更が他レイヤーに波及」も強制復帰
- PR 集計: `tdd: skip × N / enforced × M` を完了記録に出力

## worktree 推奨ワークフロー (`wt` 利用時)

```bash
wt new shiken-experiment    # 隔離 worktree でアグレッシブに test を書く・捨てる
# RED → GREEN → REFACTOR → PRUNE
# PRUNE 後、対象実装を一時的に壊して test fail 目視 (上記「PRUNE 検証手順」)
# sadoku レビュー → main へ merge
```

worktree 内では「捨てる」コストがゼロ。実装をロックする test を書いても `delete = delete` で問題ない。本流 branch を汚さない。

## 完了記録

機械検証可能項目は検証ログ (test runner 出力) をそのまま引用する。

```
worktree:          in-worktree / normal-repo
cycle:             RED -> GREEN -> REFACTOR -> PRUNE 各 phase 完了確認
                     検証ログ (RED):     [test runner output 最終行、fail を含む]
                     検証ログ (GREEN):   [test runner output 最終行、pass]
                     検証ログ (PRUNE):   各 test に対する temporary break → fail → restore → pass の出力
tests:             N kept (after PRUNE), M removed
tdd layer:         [強制 / 推奨 / スキップ可]
skip reason:       [スキップ時のみ、1 行]
```

## references/

- `testing-anti-patterns.md` — mock の存在 assert 禁止、production class への test-only method 禁止、部分 mock、snapshot 濫用、`.skip` 理由なし放置
