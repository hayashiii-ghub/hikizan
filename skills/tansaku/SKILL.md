---
name: tansaku
description: "Use this skill when something is broken and the cause is unclear — bugs, crashes, errors, regressions, unexpected test failures, behavior that doesn't match expectations — including phrasings エラー, 動かない, 落ちる, クラッシュ, バグ調査, 前は動いてた, アップデート後から, 同じ問題が再発, root cause, debug. Activate on mysterious test failures or features that used to work — even without explicit 'bug' wording."
license: MIT
when_to_use: "バグ調査, debugging, root cause, エラー原因, 動かない"
metadata:
  version: "2.0.0"
---

# tansaku (探索)

```
🌲 Using /tansaku for [purpose taken from trigger context].
```

> **hypothesis を 1 文書けるまで実装を変更しない。「とりあえず試す」「自信ある」は調査不足のサイン。**

バグ / テスト失敗 / 予期せぬ挙動の root cause investigation。

## Step 0: worktree 検出

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
[ "$GIT_DIR" != "$GIT_COMMON" ] && echo "(worktree内: $(git branch --show-current))"
```

## モード切替

| モード | 発話トリガー | 状態トリガー |
|---|---|---|
| 通常追跡 | `エラー` / `動かない` / `落ちる` / `クラッシュ` | — |
| 二分探索 | `前は動いてた` / `アップデート後から` / `更新後動かない` | — |
| 再発追跡 | `同じ問題が再発` | `good` screenshot 添付 |

## Hard Rules

- root cause を 1 文で言語化できるまで実装を変更しない (`I believe the root cause is [X] because [evidence].`)
- grep / read / log 収集 / test 再現は調査行為であり「code を触る」には含めない
- 同じ症状が修正後も残る = 停止、hypothesis 再構築
- 3 回失敗したら handoff フォーマットで停止し、ユーザに proceed 判断を求める
- 視覚バグは静的解析優先 (paint / layer trace を先に読む)
- fix が 5+ ファイルに touch するなら scope 確認 (= 別 bug の可能性)
- `Never state from memory. Run grep first.` (識別子・呼び出し関係は実物を確認、記憶で答えない)
- 外部事実 (OSS の現行仕様 / 最新バージョン / 標準) は知識カットオフ後の可能性があるため、利用可能な検索・fetch・一次ソースで裏取りしてから引用する (§3.10 ファクトチェック原則)
- PR / branch / step を独自連番 (PR-1 等) で呼ばない。issue 名 / 機能名 / branch 名で呼ぶ。重複時のみ -v2, -v3 ... のサフィックスを使う

## 通常追跡モード

1. **症状をそのまま列挙**: error message, stack trace, 再現手順, 期待値, 実際の値
2. **hypothesis を 1 文**: `I believe the root cause is [X] because [evidence].`
3. **証拠 1 つで confirm / discard**: instrument (log, breakpoint, grep) を 1 つだけ走らせる
4. confirm → fix へ。discard → hypothesis を再構築
5. fix 後、**fix 前後の同 input での挙動 diff** を完了記録に記載 (要約禁止)

## 二分探索モード

1. non-interactive な test command を確定 (CI でも回る形)
2. good commit と bad commit を確定
3. `git bisect run <command>` で culprit commit を特定
4. culprit の diff を読み、root cause を 1 文に言語化
5. fix → 通常追跡モードの手順 5 に合流

## 再発追跡モード

- 過去の症状と参照を対比 (`good` screenshot / 過去のログ / 過去 PR)
- pass / fail check を定義 (機械判定可能な形)
- 過去の修正 commit を grep し、回帰した経路を特定
- regression guard test を必ず追加 (`shiken` のフォーマットに従う)

## Handoff Intake

`kouchiku` または user から呼ばれる時に期待する入力。足りない場合は推測で補完せず、停止条件として扱い、欠落項目を呼び出し元に問い合わせる。

```
handoff: tansaku
reason: [原因未確定 / 予期しない test failure / 再現不明 の理由]
symptom: [何が起きているか、1 文]
expected: [本来こうあるべき値 / 挙動]
actual: [実際こうなっている値 / 挙動]
evidence:
  - [error message / stack trace / log]
  - [再現手順]
scope hint:
  - [影響範囲 / 直前の変更 / 触ったファイル]
expected return:
  - root cause (1 文)
  - fix 候補 (実装は呼び出し元に戻す、または shiken に forward)
```

## Handoff Forward

原因が確定したら、bugfix 実装や regression guard が必要な場合は `shiken` に渡す。tansaku は root cause と再現条件を固定し、TDD の実装 discipline は持ち込まない。

```
handoff: shiken
reason: root cause 確定、regression guard が必要
root cause: [1 文]
failing behavior: [同 input での before]
target behavior: [after として期待する状態]
test target:
  - [file/module]
  - [behavior to assert]
constraints:
  - mock 呼び出し回数 assert 禁止
  - production に test-only API 追加禁止
expected return:
  - RED log
  - GREEN log
  - PRUNE result
```

## subagent 並列許可 — gate (c)

3+ の独立した test failure (異なるファイル / サブシステム / 共有 state 無し) のときのみ並列起動許可、最大 3。各 subagent は症状抽出と hypothesis 形成までを担当し、fix 実行は親 controller に戻す。

並列起動禁止:
- 同一 root cause の疑いがある複数 failure (= 1 つの hypothesis で同時に解決する可能性)
- ファイル横断的に state を共有する failure (race 等)
- UI / 視覚絡み (目視必須)

## 3 回失敗時の handoff フォーマット

```
hypothesis attempts:
  1. [hypothesis] -> [evidence run] -> [discarded because ...]
  2. ...
  3. ...
current best guess: [X]
remaining unknowns: [...]
recommended next step: [...]
ユーザの proceed 判断を求めます。
```

## 完了記録

`Confirmed` には fix 前後の同 input に対する挙動 diff を**そのまま引用**する。要約・「直りました」だけの自己申告は禁止。

```
worktree:          in-worktree / normal-repo
Root cause:        [what was wrong, file:line]
Fix:               [what changed, file:line]
Confirmed:         同 input での fix 前後の挙動 diff
                     before: [output / error / state — そのまま]
                     after:  [output / state — そのまま]
Tests:             [pass/fail count, regression test location]
                     検証ログ: [test command 最終 summary 行]
Regression guard:  [test file:line] or [none, reason]
Status:            resolved / resolved-with-caveats / blocked
```

## references/

- `logging-techniques.md` — instrument を 1 つだけ仕込むときの典型パターン (console / breakpoint / git log -S / strace / network panel)
