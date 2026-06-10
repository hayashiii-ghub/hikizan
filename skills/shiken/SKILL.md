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

TDD discipline。失敗するテストを先に書き fail を**目視**してから実装する。GREEN 後に PRUNE で test を最小化する。1 cycle は原則 1 vertical behavior slice、slice の分解は `kouchiku` が担う。

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

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較。異なれば worktree 内 — branch 名を完了記録の `worktree` 行に記録する。一時的な test 変更が大きい場合のみ利用環境の標準機能で隔離 worktree / sandbox を使ってよい (作成・削除はその標準機能に従う)。隔離環境でも RED → GREEN → REFACTOR → PRUNE の順序と PRUNE 検証は省略しない。

## 起動 (router)

| 入力トリガー | 状態トリガー |
| --- | --- |
| `TDDで` / `テストから書いて` | 下記「起動条件 (層分け)」で判定 |

入力トリガーは明示 opt-in で kouchiku 計画実行との競合を避ける。直接起動時は user request から vertical slice を 1 文で明示し、scope 分割 / 設計判断 / root cause diagnosis / 複数 slice が必要なら RED に入らず `kouchiku` へ handoff する。

## 必須 (invariant)

- **書く側**: 失敗するテストを先に書き、本セッション内で fail を**目視**するまで実装コードを書かない
- **検証側**: PRUNE 後に残った各 test は、vertical slice の observable output を一時的に壊したとき必ず失敗することを目視確認する。失敗しない test = 何も検証していない (= 削除対象)
- **PRUNE 復元**: 壊して確認した後は元に戻し、`git status` が clean に戻ったことを確認する (中断時に working tree を壊したまま放置しない)
- `kouchiku` handoff に `vertical slice` が無ければ RED に入らず差し戻す。直接起動で 1 slice に言語化できなければ scope を自分で分割せず `kouchiku` へ handoff
- `coverage gap` を検出しても追加 slice を勝手に実装しない。gap を return に残し次 slice 判断は `kouchiku` に戻す
- RED-GREEN サイクルは **inline 必須**、subagent 委譲不可 (目視必須)
- assert は private helper 形状ではなく slice の observable output に向ける

## サイクル: RED → GREEN → REFACTOR → PRUNE (既定手順)

1 cycle は 1 vertical behavior slice を閉じる単位。既存 test 構造に合わせて unit / integration / component / e2e を選んでよい。

| Phase | 動作 |
| --- | --- |
| RED | 失敗する test を 1 つ書く、test runner で fail を目視 |
| GREEN | test を pass させる最小実装、test runner で pass を目視 |
| REFACTOR | duplication 除去 / 命名改善、テストは green のまま |
| **PRUNE** | 各 test を slice behavior 基準で評価し不要を削除 |

各 phase 遷移は test runner の出力 (最終 summary 行) で確認し完了記録に引用する (「目視した」だけの自己申告は不可)。**Slice 粒度**: 原則 1 vertical slice = 1 kept test。distinct な observable behavior の edge case は別 slice。PRUNE 評価基準と検証手順は `references/testing-anti-patterns.md`。

**PRUNE 検証 (各 test 必須)**: vertical slice の observable output を一時的に壊して test failure を確認 → 元に戻して pass を再確認 → `git status` clean を確認。隔離 worktree を使うか、対象 file の現在状態を退避して最小変更で壊す (unrelated な dirty file があれば作業全体を stash せず scope を確認)。

```bash
cp path/to/impl /tmp/hikizan-prune.impl
# observable output だけを一時的に壊す → <test runner> <test> で fail を確認
cp /tmp/hikizan-prune.impl path/to/impl
# <test runner> <test> で pass を再確認 → git status で clean を確認
```

## 起動条件 (TDD トリガー層分け、言語非依存)

| レイヤー | 例 | TDD 扱い |
| --- | --- | --- |
| 純ロジック | validator / formatter / reducer / 副作用なし関数 / store | **必須** RED-GREEN-REFACTOR |
| ビジネスルール | 価格計算 / 権限判定 / 状態遷移 | **必須** |
| バグ修正 (全レイヤー) | 再現テスト先行 | **必須** regression guard |
| API 層 | client / query / mutation / data transform | **必須** (mock 境界明示) |
| インタラクション | event → state, form submit, a11y 要件 | **推奨** |
| 純スタイル / レイアウト | style 単独 / spacing 調整 | **スキップ可** (理由必須) |
| 文言 / asset | i18n 語彙 / icon / transition | **スキップ可** (理由必須) |
| 設定 / build / CI | package manifest / build 設定 / workflow | **必須** 動作確認 (実行ログ) |

**入口判定**: 変更ファイルの種別分布 / 既存テストの有無 / 変更意図 tag (bugfix・feature・refactor・style・chore) / 純粋関数か副作用ありか。**スキップガード**: スキップ時は完了記録に 1 行必須 (`tdd: skip — <理由>`)。ロジック行に 1 行でも触れたら必須に戻す。

## Handoff Return

RED → GREEN → PRUNE に落としきり、GREEN 後は実装判断を広げず呼び出し元へ検証ログ付きで返す。共通契約の handoff block に加え `implemented behavior / vertical slice / test level (chosen + reason) / coverage gap / RED・GREEN・PRUNE log / prune witness / files changed / verification` を含める。

## 完了記録 (必須)

機械検証可能項目は test runner 出力をそのまま引用する。

```
worktree / vertical slice: [entry / behavior / observable output / excluded layers]
test level:   [unit / integration / component / e2e] + reason
coverage gap: [accepted gap / returned decision / none]
cycle:        RED -> GREEN -> REFACTOR -> PRUNE
                検証ログ (RED):   [test runner 最終行、fail を含む]
                検証ログ (GREEN): [test runner 最終行、pass]
                検証ログ (PRUNE): observable output break → fail → restore → pass の出力
prune witness: [どの observable output を壊して fail を確認したか]
restore:      working tree clean (git status) / 検証ログ: [git status --short の出力 / "clean"]
tests:        N kept (after PRUNE), M removed
tdd layer:    [必須 / 推奨 / スキップ可]  skip reason: [スキップ時のみ 1 行]
```

## references/

- `testing-anti-patterns.md` — PRUNE 評価基準 / mock 存在 assert 不可 / test-only method 不可 / 部分 mock / snapshot 濫用 / `.skip` 理由なし放置
