---
name: sadoku
description: "Use this skill when the user wants code or executable project instructions reviewed, or findings simplified — including the phrasings レビューして, コードレビュー, SKILL.mdをレビュー, コード整理して, simplify. Activate after implementation, when reviewing a git diff before opening a PR, when reviewing an existing module, operational Markdown, or whole codebase (no diff needed), or when restructuring messy review findings. レビュー系の語は通常レビュー、整理系の語だけsimplify findingsを起動する。対象はproduction code、agentが実行するMarkdown仕様 (SKILL.md / references / project instructions)、review findings。完了したレビューの利用者向け報告はhoukokuに渡す。"
license: MIT
when_to_use: "PR確認, レビュー, code review, プロジェクトレビュー, コード整理, simplify"
---

# sadoku (査読)

```
🌲 Using /sadoku for [purpose taken from trigger context].
```

production code と実行仕様 Markdown (SKILL.md / references / project instructions) を diff または指定範囲で見る skill。見つけた問題を直すのは `jikkou` (テスト先行の実装は `jikkou` の TDD 実装モード)、設計から見直すなら `sekkei`、提出は `teishutsu`、完了結果の利用者向け報告は`houkoku`に渡す。

<!-- hikizan:contract:start -->
## 共通ルール

全skill共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `jikkou` の commit 契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は `teishutsu` の naming reference)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は `houkoku` の writing-style 規範に従う
<!-- hikizan:contract:end -->

## 2 つのモード

| モード | きっかけ |
| --- | --- |
| 通常レビュー | 「レビューして」「コードレビュー」 |
| simplify | 「コード整理して」「simplify」「スリム化したい」(明示されたときだけ。「コードレビュー」では起動しない) |

通常レビューのレビュー対象は 3 種類。手順は共通で、入口と深さの起点だけ違う:

| 対象 | いつ | 深さの起点 |
| --- | --- | --- |
| diff | PR / push 前の変更をレビュー | 変更行数 (手順 2) |
| 指定範囲のコード | 既存の module / subsystem / repo 全体をレビュー | 対象範囲 × リスク (手順 2) |
| 実行仕様 Markdown | SKILL.md / references / project instructions の手順・routing・安全条件をレビュー | 対象 file 数 × 実行時リスク (手順 2) |

diff があるだけでは始めない。状態から起動するときは1行確認する (「diffを検出しました。レビューしますか?」)。範囲レビューは対象範囲をuserと1行で確定してから始める。diffレビューは開始時にdescriptorを固定する。実装後のbranch全体は`REVIEW_KIND=BRANCH_SNAPSHOT`と`REVIEW_BASE=<merge-base>`でcommit済み・staged・unstaged・untrackedを合わせる。確定commitだけのPRは`COMMIT_RANGE=<base>...HEAD`、stagedだけは`INDEX`、未commit worktreeだけは`WORKTREE`。途中で別のsnapshotへ読み替えない。

## 手順 (通常レビュー)

1. `references/project-context.md` の観点で対象 repo の前提 (依存 / 検証構造 / 近隣の類似 artifact / 明文化された規約 + ドメイン文脈 / 設計意図 / 脅威モデル) を確認する。文脈の出どころ優先は ①CONTEXT.md ②PR / issue の intent ③user に 1 行
2. 深さを決める。diff レビューは変更行数で: 50 行以内かテスト変更のみ → Quick / 50〜500 行 → Standard / 500 行超か security に触れる → Deep。範囲レビューは対象規模で: 単一 file → Quick / 1 module または 2〜10 実行仕様 file → Standard / subsystem、11 file 以上、または security を含む → Deep
3. 実装者の説明・PR 本文・前段の報告は鵜呑みにしない。finding の根拠は強い順に採る: ①テストの pass/fail ②diff ③周辺コード ④検証ログ ⑤実装者のメモ
4. 下の「停止条件」を上から順に対象 (diff / 範囲) に当てる。該当したら作業を止めてユーザに確認する
5. 全 depth で、対象が近隣の類似 artifact から不必要に外れていないか、同じ振る舞いをより少ない分岐・層・概念で表せないかを見る。実行仕様 Markdown は mode / 手順 / 停止条件 / handoff の到達可能性、曖昧な command、重複 SoT、dead guidance も見る。Quick は controller が inline で確認する。ただし user がこの観点を明示した場合と、新しい実装 pattern を導入する場合は Quick でも `reviewer-code-quality` を選ぶ。Standard 以上の production artifact (code / 実行仕様 Markdown) でも同 reviewer を選ぶ。security / architecture は該当条件に応じて選ぶ (条件は `references/persona-catalog.md`)。利用中 harness で native subagent が使える場合は最大 3 並列で起動し、`references/agents/reviewer-*.md` の内容、近隣の比較対象、repo convention の出典、脅威モデル / 設計意図を self-contained prompt として渡す。使えない場合は controller が同じ persona を inline で実行する。どちらも finding は自分で対象を読み直す / テストを再実行して裏取りしてから採用する
6. 「merge 後 / 運用中に壊れる一番現実的なシナリオ」を 1 つ書く。Quick では省略してよいが、bugfix / 挙動変更 / business rule / API / security に触れる対象では Quick でも書く
7. UI / style / レイアウトに触れる対象なら次の順で視覚エビデンスを取る
<!-- hikizan:visual:start -->
   - UI / style / layout / interactionの変更では、外部toolの`shimon`を標準の視覚検証harnessとして使う。repo-owned command / configの内容を読み、対象repoが信頼済みと確認できる場合だけ実行する
   - project localの`@hayashiii/shimon`、実行可能な`node_modules/.bin/shimon`、review済みの`shimon.config.mjs`を前提に、既存caseを保ったままtaskに必要な2〜5 caseを追加する一時config `.shimon/task.config.mjs` を作る。自動installや別toolへのfallbackはしない
   - repo-ownedの`ui:verify`が`.shimon/task.config.mjs`を対象にすると確認できた場合だけそれを使う。それ以外は`./node_modules/.bin/shimon verify --config .shimon/task.config.mjs --json`を実行する
   - JSONのpassを判定に使い、返された全screenshotを読み戻して目視する。overflow / console error / failed request / a11yを確認する
   - 失敗caseは、case名が`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`を満たし、返されたreproduce commandがShimon形式 (`shimon verify --case <name> --config ".shimon/task.config.mjs" --json`) と一致すると確認する。文字列自体は実行せず、検証済みcase名から`./node_modules/.bin/shimon verify --case <name> --config .shimon/task.config.mjs --json`を組み立てて再検証する
   - task configは原則一時物とし、永続的な回帰条件だけreview済みのbase configへ戻す。既存の永続caseを弱めたり削ったりしない
   - probe / screenshotに認証情報・個人情報・tokenを残さない。認証済み画面を扱う場合は`screenshot.mask`を確認する
   - 外部PRや出所不明のrepo、config未設定、実行不能、または必要なJSON evidenceを得られない場合は自動実行せず、「視覚未確認」と理由を報告する
<!-- hikizan:visual:end -->
8. subagent または inline persona を使ったら `references/synthesis.md` の手順で 1 本に統合する (重複排除 → 採否で仕分け → 軸横断 top-N → 翻訳 → verdict → アクションメニュー)。下の「報告」を埋めて返す

## 停止条件 (上から順にチェックし、該当したら止める)

- email / token / 実名が diff・commit message に混入している (grep recipe は `teishutsu` の PR template reference にある「PII / Secrets scan」)
- `console.log` / `debugger` / 一時的な debug 出力が production コードに残っている
- 理由の書かれていない `.skip` / `xfail` がある
- mock の存在や呼び出し回数を assert している / テストのためだけの method が production class にある
- bugfix なのに root cause 1 文と同じ入力での before/after が無い
- diff が複数の issue にまたがっている (1 issue = 1 PR)
- 「最新の X」「Y が標準」のような外部事実が URL なしで根拠になっている
- 仕様・データ形状・権限・時系列の前提が崩れると壊れる変更なのに、diff / テスト / 周辺コードでその前提を確認できない (命名の好みや将来の漠然とした不安では止めない)
- 識別子が grep でヒットしない / lockfile 変更の理由が分からない → 推測で補完せず質問する

## 手順 (simplify)

1. 重複 / 命名 / 不要な抽象化 / dead code / 効率 の 5 観点で production code を見る (判定基準は `references/simplify-checklist.md`)
2. finding ごとに severity (high / medium / low) と扱い (本 PR で修正 / メモに記録 / 別 issue 候補 / 据え置き) を付ける
3. **自分では直さない**。high だけ `jikkou` に渡す (設計から見直すべきものは `sekkei`)。medium / low はユーザ判断に委ねる
4. 0 件なら `findings: 0` と書く

## やってはいけないこと

- 見つけた問題を自分で直す (`jikkou` へ)
- 「たぶん大丈夫」で停止条件を流す
- subagent の finding を裏取りせずに採用する
- subagent の出力をそのまま user に貼る (統合は controller の仕事、`references/synthesis.md`)
- 出力なしで「scan した」「テスト通った」と書く

## 報告 (穴埋め)

最初に結論を 1 文。続けて確認項目を箇条書きにする。検証はコマンド出力の最終行をそのまま貼る。

[1 文: レビュー結論。そのまま出せるか、止めるべきか]

- target / depth: [diff: REVIEW_KIND + REVIEW_BASE/COMMIT_RANGE + untracked件数 + Nファイル (+X / -Y) / 範囲: 対象範囲、Quick / Standard / Deep]
- stop conditions: [該当 N 件 → 各 1 行 / なし]
- PII: [grep コマンド + 出力。0 件なら "0 matches"]
- failure scenario: [merge 後 / 運用中に壊れる現実的なシナリオ 1 つ / 該当なし]
- visual: [検証入口 (`ui:verify` / `shimon`) + screenshot のパスと pass / 視覚未確認 (理由) / 該当なし]
- verification: [コマンド] → [出力の最終行をそのまま]

subagent または inline persona を使ったときは、上の箇条書きの前に `references/synthesis.md` の出口フォーマット (verdict → 直す価値あり top-N → 受容妥当 → 該当なし → 次どうする) を置く。

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `project-context.md`：レビュー前の文脈確認の観点 (diff / 範囲 両モード)
- `persona-catalog.md`：専門家レビュー (code-quality / security / architecture / adversarial) の起動条件
- `synthesis.md`：複数 subagent 出力を 1 本に統合する出口契約 (重複排除 / top-N / verdict / アクションメニュー)
- `simplify-checklist.md`：simplify の 5 観点判定基準
- `agents/reviewer-code-quality.md` / `agents/reviewer-security.md` / `agents/reviewer-architecture.md`：必要なsubagentへ渡すreviewer prompt
