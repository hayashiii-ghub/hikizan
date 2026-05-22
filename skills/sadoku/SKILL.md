---
name: sadoku
description: "Use this skill when the user wants code reviewed or findings simplified — including the phrasings レビューして, コードレビュー, 整理して, simplify. Activate after implementation, when reviewing a git diff before opening a PR, or when restructuring messy findings — even when the user doesn't say 'review' explicitly."
license: MIT
when_to_use: "PR確認, レビュー, code review, 整理, simplify"
---

# sadoku (査読)

```
🌲 Using /sadoku for [purpose taken from trigger context].
```

「diff を見る」ための skill。通常レビュー / simplify findings の 2 モード。実装行為 (計画実行) と原因調査は `kouchiku`、TDD は `shiken`、PR 本文ドラフトと提出フローは `teishutsu` に分離。

## Step 0: worktree 検出

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較する。異なれば worktree 内 — branch 名とともに表示し、完了記録の `worktree` 行に記録する。worktree の作成・削除はこの skill では行わない。

## モード切替


| モード               | 入力トリガー                                        | 状態トリガー  |
| ----------------- | --------------------------------------------- | ------- |
| 通常レビュー            | `レビューして`                                      | diff 検出 |
| simplify findings | `整理して` / `simplify` / `整理ポイントある?` / `スリム化したい` | —       |


**compound trigger**: `コードレビュー` / `コードレビューして` は **通常レビュー → simplify findings** を順に実行する (それぞれ独立 section として出力)。

状態トリガーは誤起動回避のため、検出後に確認 prompt を 1 行挟む (`diff を検出しました。レビューしますか?`)。複数モードが成立しうる場合は入力トリガーを優先。

## Handoff Intake

`kouchiku` / `shiken` からの handoff block がある場合は、diff だけでなく前段の判断と検証ログも review evidence として読む。足りない場合は推測で補完せず、通常レビューの停止条件として扱う。

期待する入力:

```
handoff: sadoku
reason: 実装完了、PR 前のレビュー要求
change intent: [何を解決したか]
files changed:
  - [path]
verification:
  - [command] -> pass / fail
tdd:
  - vertical slice: [entry / behavior / observable output / excluded layers]
  - test level: [unit / integration / component / e2e] + reason
  - coverage gap: [accepted gap / returned decision / none]
  - RED: [...]
  - GREEN: [...]
  - PRUNE: [...]
  - prune witness: [どの observable output を壊して fail を確認したか]
root cause:
  - [bugfix / diagnosis があれば kouchiku の root cause 1 文 + evidence]
confirmed:
  - [bugfix / diagnosis があれば同 input の before / after diff]
scope notes:
  - [やらなかったこと]
review focus:
  - [特に見てほしい観点]
```

## 通常レビューモード

深さ判定 → diff 読解 → Skeptical Review Lens → 停止条件チェック → 専門家レビュー → 完了記録。

diff 読解に入る前に `references/project-context.md` を読み、変更ファイルの依存関係 / テスト構造 / 命名規則 / touch ファイル数を確認する。

`shiken` の return がある場合は、残った test が vertical slice の observable output を守っているかを review evidence として確認する。`coverage gap` は `kouchiku` が受け入れたか、後続 slice に切ったかを見る。`sadoku` は新しい slice を実装せず、必要なら finding として返す。

### Skeptical Review Lens

実装者の説明・PR 本文・handoff context は仮説として読む。review finding の根拠には、diff / tests / verification log / surrounding code を使う。

**Evidence hierarchy**

1. failing / passing test output
2. diff
3. surrounding code
4. verification logs
5. implementation notes / PR description

通常レビューでは次の 3 点を確認する:

1. この変更が正しいために必要な前提は何か?
2. その前提は diff / tests / verification log / surrounding code で確認できるか?
3. merge 後に壊れる最も現実的なシナリオは何か?

`failure scenario` は Standard / Deep では必ず 1 つ書く。Quick は明確な挙動変更がなければ `not applicable` でよい。bugfix / behavior change / business rule / API contract / security-sensitive change では深さに関係なく必須。

**深さ判定**


| 深さ       | 条件                     | 動作                                       |
| -------- | ---------------------- | ---------------------------------------- |
| Quick    | 50 行以内、テスト変更のみ等        | 停止条件チェックのみ                               |
| Standard | 50〜500 行               | 停止条件 + 専門家レビュー (security / architecture) |
| Deep     | 500 行超、または security 接触 | Standard に加えて adversarial レビュー           |


**専門家レビューの起動**

Standard 以上で security / architecture 観点が必要な場合のみ subagent 起動。条件と persona は `references/persona-catalog.md`。subagent 成果物は必ず main 側で git diff / file 読み / test 再実行で裏取り。

## simplify findings モード

実装後の production code を「整理」観点 (重複削除 / 命名統一 / 不要な抽象化除去 / dead code 削除 / efficiency 改善) で review し、**findings を出すが実装はしない**。実装は kouchiku に handoff block で委譲する。

- **入力 trigger only** (state trigger を持たない、default の通常レビューに含めない)
- **`コードレビュー` 経由の compound 起動時**: 通常レビューの完了後、独立 section として simplify findings を出す (severity 順位で混ざらないようにする)
- **severity 付き** で出す: high / medium / low、kouchiku に振るのは high severity のみが default
- **disposition (処置) 必須** で出す: 各 finding に「本 PR で修正 / 『実装中に分かったこと』に記録 / 別 issue 候補 / 据え置き」のいずれかを書く。low severity の default は「記録のみ」、medium / high はユーザに判断を委ねる

### 5 観点

詳細と各観点の判定基準は `references/simplify-checklist.md` を参照。


| 観点         | 例                                           |
| ---------- | ------------------------------------------- |
| 重複         | 3 箇所以上の類似 code、共通化候補                        |
| 命名         | 同 module 内の命名揺れ、慣用と外れる用語                    |
| 不要な抽象化     | 1 箇所からしか呼ばれない wrapper、premature な generic   |
| dead code  | 未使用 export / private function / 到達不能 branch |
| efficiency | 明確な改善余地 (O(n²) → O(n) 等、計測不要な範囲)            |


### 出力フォーマット

```
## simplify findings

scope:     [対象 file / 範囲]

### finding 1
severity:           high / medium / low
category:           重複 / 命名 / 抽象化 / dead code / efficiency
file:               path:line-range
issue:              [問題、1-2 文]
evidence:           [該当コード片 1-3 行を引用、そのまま]
recommend:          [提案、1-2 文]
disposition:        本 PR で修正 / 「実装中に分かったこと」に記録 / 別 issue 候補 / 据え置き
disposition_reason: コスト / リスク / 別 issue 値 の 3 軸で 1 行
handoff:            kouchiku (high severity のみ) / user 判断 (medium / low)

### finding 2
...
```

findings が 0 件なら `findings: 0` を明示。

### handoff (実装委譲)

high severity finding は kouchiku に handoff block で実装委譲する:

```
handoff: kouchiku
reason: simplify finding (high severity) の反映実装
context: [対象 finding の category + file:line]
evidence:
  - [該当コード片]
expected return:
  - 整理後の diff
  - verification log (test pass / lint pass)
```

medium / low は `teishutsu` の PR 本文ドラフト時に「実装中に分かったこと」へ渡すか、据え置き判断を user に委ねる。

## 停止条件

以下のいずれかに該当したら**作業を止めてユーザに確認**:

- 破壊的な自動実行 (例: `rm -rf`, `git reset --hard`, force push 等) を明示確認なしで走らせていないか
- diff 内の未知の識別子 (識別子が grep でヒットしないなら、補完せず質問)
- 依存追加の妥当性が不明 (lockfile 変更があれば理由を確認)
- **review finding / commit / release notes に PII / Secrets が混入している** (email, token, 個人名等)。grep recipe は `skills/teishutsu/references/pr-template.md`「PII / Secrets scan」節を共通 SoT とする
- **テスト最小性違反** (いずれか):
  - mock の存在・呼び出し回数を assert している test
  - production class に test-only method が追加されている
  - 部分 mock (実 API の一部 field だけ) で structural assumption が隠れている
  - snapshot test の濫用 (small diff で全更新)
  - `.skip` / `xfail` が理由コメントなしで残っている
  - `shiken` return があるのに vertical slice / test level / coverage gap / prune witness が欠けている
  - kept test が observable output ではなく private helper 形状や mock call count を守っている
- **PR 粒度違反**: diff が複数 issue にまたがっている (= 1 issue = 1 PR ルール違反)
- **未確認の外部事実引用**: 「最新の X バージョン」「Y 標準」のような外部事実が裏取りなしで review finding / コメントに混入している (ファクトチェック原則、URL 引用必須)
- **root cause 証跡不足**: bugfix / diagnosis を含む diff で root cause 1 文、evidence、同 input の before / after diff が無い
- **前提未証明**: 仕様 / 既存挙動 / 外部制約 / データ形状 / 権限 / 時系列に依存し、その前提が崩れると挙動破壊・security issue・data loss・誤請求などにつながるのに、diff / tests / verification log / surrounding code で確認できない。単なる命名好み、軽微な文言好み、将来拡張の不安、既存設計への不満だけでは止めない
- **反証不足**: bugfix / behavior change / business rule / API contract / security-sensitive change で、壊れていた入力・守るべき出力・回帰防止 test または verification がつながっていない
- **debug instrument 残留**: `console.log` / `debugger` / `dump()` / 一時 log tag など、調査用 instrument が production code に残っている

## Hard Rules

- PR / branch / step の命名は `kouchiku` Hard Rules に従う
- diff 内のシンボル参照 (関数 / クラス / 変数 の呼び出し関係 / 定義位置) は LSP を優先、テキスト探索 (PII scan / TODO / コメント文字列) は grep を使う。LSP 未設定環境では grep にフォールバック (公式 LSP plugin の install は README「LSP 併用」節)

## 完了記録

機械検証可能項目は検証ログ (command + 出力末尾) を**そのまま引用**する。**要約・自己申告は不可**。

```
worktree:         in-worktree / normal-repo
files changed:    N (+X -Y)
scope:            on target / drift: [不足事項]
停止条件:         N found / N fixed
                    検証ログ: [scan command + 出力末尾 / 0件は "0 matches"]
tests:            N added, M essential
                    検証ログ: [test command 最終 summary 行]
verification:     [command] -> pass / fail
                    検証ログ: [出力末尾 3-5 行、失敗時は full error]
root cause:       present / missing / not applicable
                    検証ログ: [handoff の root cause / before-after diff]
failure scenario: [1 つ / not applicable]
PII scan:         clean / found: [...]
                    検証ログ: [grep command + 出力 / 0件は "0 matches"]
文章:             伝わる / 伝わらない (伝わらない場合: 何が伝わらないか)    ※ 自己申告
```

## references/

- `project-context.md` — diff 読解時の文脈抽出方針
- `persona-catalog.md` — 専門家レビュー (security / architecture / adversarial) の persona 起動条件
- `agents/reviewer-security.md` / `agents/reviewer-architecture.md` — 専門家レビュー subagent prompt
- `simplify-checklist.md` — simplify findings モードの 5 観点判定基準と書き直し方
