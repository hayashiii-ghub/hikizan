---
name: sadoku
description: "Use this skill when the user wants code reviewed or findings simplified — including the phrasings レビューして, コードレビュー, 整理して, simplify. Activate after implementation, when reviewing a git diff before opening a PR, or when restructuring messy findings — even when the user doesn't say 'review' explicitly. レビュー系の語 (レビューして / コードレビュー) は通常レビュー、整理系の語 (整理して / simplify) のみ simplify findings を起動する。"
license: MIT
when_to_use: "PR確認, レビュー, code review, 整理, simplify"
---

# sadoku (査読)

```
🌲 Using /sadoku for [purpose taken from trigger context].
```

「diff を見る」ための skill。通常レビュー / simplify findings の 2 モード。実装行為と原因調査は `kouchiku`、TDD は `shiken`、PR 本文ドラフトと提出フローは `teishutsu` に分離する。

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

| モード | 入力トリガー | 動作 |
| --- | --- | --- |
| 通常レビュー | `レビューして` / `コードレビュー` | 深さ判定 → diff 読解 → 停止条件 → (Standard 以上) 専門家レビュー → 完了記録 |
| simplify findings | `整理して` / `simplify` / `スリム化したい` | 整理観点で findings を出すが実装はしない (実装は kouchiku へ handoff) |

- **simplify は明示トリガー専用**。`コードレビュー` は通常レビューのみを起動する (整理が必要なら別途 `整理して`)。
- diff を検出しただけでは起動しない (CC の自動起動は description 照合のみで、状態の自動検出は保証されない)。レビューを始める前に 1 行確認 (`diff を検出しました。レビューしますか?`) を挟んでよい。

## Handoff Intake

`kouchiku` / `shiken` からの handoff block があれば、diff だけでなく前段の判断と検証ログも review evidence として読む。足りなければ推測で補完せず停止条件として扱う。期待入力は `change intent / files changed / verification / tdd (slice・level・gap・RED/GREEN/PRUNE・prune witness) / root cause / review focus`。

## 通常レビュー (既定手順)

diff 読解前に `references/project-context.md` を読み、依存関係 / テスト構造 / 命名規則 / touch ファイル数を確認する。

**Skeptical Review Lens** (必須): 実装者の説明・PR 本文・handoff は仮説として読む。finding の根拠は evidence hierarchy ① failing/passing test → ② diff → ③ surrounding code → ④ verification log → ⑤ implementation notes の順で上位を優先。確認する 3 点: ①この変更が正しい前提は何か ②それは diff/tests/log/surrounding で確認できるか ③merge 後に壊れる最も現実的なシナリオ。`failure scenario` は Standard / Deep では必ず 1 つ、bugfix / behavior change / business rule / API contract / security では深さに関係なく必須。

**深さ判定**

| 深さ | 条件 | 動作 |
| --- | --- | --- |
| Quick | 50 行以内 / テスト変更のみ | 停止条件チェックのみ |
| Standard | 50〜500 行 | 停止条件 + 専門家レビュー |
| Deep | 500 行超 / security 接触 | Standard + adversarial レビュー |

**専門家レビュー**: Standard 以上で security / architecture 観点が該当する場合のみ subagent 起動 (並列上限 3)。起動条件は `references/persona-catalog.md`。subagent 定義は plugin の `agents/reviewer-security.md` / `agents/reviewer-architecture.md` (CC は first-class subagent として discover、他ハーネスは `references/agents/` を fallback に使う、両者は同一内容)。subagent 成果物は必ず main 側で git diff / Read / test 再実行で裏取りする。adversarial persona は inline 実行 (subagent 委譲しない)。

## simplify findings (既定手順)

production code を整理観点 (重複 / 命名 / 不要な抽象化 / dead code / efficiency) で review し、**findings を出すが実装はしない**。5 観点の判定基準は `references/simplify-checklist.md`。severity (high/medium/low) と disposition (本 PR 修正 / 「実装中に分かったこと」記録 / 別 issue 候補 / 据え置き) を各 finding に付す。high severity のみ `kouchiku` に handoff で実装委譲、medium/low は user 判断。findings 0 件なら `findings: 0` を明示。

## 必須 (停止条件 invariant)

以下のいずれかに該当したら作業を止めてユーザに確認する:

- **PII / Secrets 混入**: review finding / commit / release notes に email / token / 個人名等。grep recipe は `skills/teishutsu/references/pr-template.md`「PII / Secrets scan」節を共通 SoT とする
- **テスト最小性違反**: mock 存在/回数 assert / production class への test-only method / 部分 mock で structural assumption 隠蔽 / snapshot 濫用 / 理由なし `.skip`・`xfail` / `shiken` return に slice・level・gap・prune witness 欠落 / kept test が observable output でなく private 形状や mock call count を守っている
- **PR 粒度違反**: diff が複数 issue にまたがる (1 issue = 1 PR)
- **未確認の外部事実引用**: 「最新の X」「Y 標準」が裏取りなしで finding に混入 (URL 引用必須)
- **root cause 証跡不足**: bugfix / diagnosis で root cause 1 文・evidence・同 input の before/after が無い
- **前提未証明 / 反証不足**: 仕様・既存挙動・外部制約・データ形状・権限・時系列に依存し、崩れると挙動破壊 / security / data loss / 誤請求につながるのに diff/tests/log/surrounding で確認できない。命名好みや軽微な文言、将来不安だけでは止めない
- **debug instrument 残留**: `console.log` / `debugger` / `dump()` / 一時 log tag が production に残っている
- 識別子が grep でヒットしない / 依存追加の妥当性不明 (lockfile 変更の理由) は補完せず質問する
- diff 内シンボル参照は LSP 優先、PII scan / コメント文字列は grep (LSP 未設定なら grep)

## 完了記録 (必須)

機械検証可能項目は検証ログ (command + 出力末尾) を**そのまま引用**する。要約・自己申告は不可。

```
worktree / files changed: N (+X -Y) / scope: on target / drift
停止条件:    N found / N fixed
               検証ログ: [scan command + 出力末尾 / 0 件は "0 matches"]
tests:       N added, M essential / 検証ログ: [test command 最終 summary 行]
verification: [command] -> pass / fail / 検証ログ: [出力末尾 3-5 行、失敗時 full error]
root cause:  present / missing / not applicable / 検証ログ: [root cause / before-after]
failure scenario: [1 つ / not applicable]
PII scan:    clean / found / 検証ログ: [grep command + 出力 / 0 件は "0 matches"]
```

## references/

- `project-context.md` — diff 読解時の文脈抽出方針
- `persona-catalog.md` — 専門家レビュー (security / architecture / adversarial) の起動条件
- `simplify-checklist.md` — simplify findings の 5 観点判定基準
- `agents/reviewer-security.md` / `agents/reviewer-architecture.md` — 他ハーネス向け fallback (plugin `agents/` と同一内容)
