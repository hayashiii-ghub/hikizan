---
title: Skill ワークフロー
description: tansaku / sadoku / sekkei / jikkou / teishutsu の境界、トリガー、handoff
---

# Skill ワークフロー

> **目的:** skill の境界・起動トリガー・handoff を 1 箇所で確認できるようにする。
>
> **対象範囲:** 実装パイプラインの 5 skill (`tansaku` / `sekkei` / `jikkou` / `sadoku` / `teishutsu`)。文章作成の `shippitsu` はこの pipeline から独立して動く (起動語は下の生成トリガー表に含む、詳細は `../skills/shippitsu/SKILL.md`)。個別の手順・mode 定義の正本は各 `SKILL.md`。本書はその転記をしない。

---

## 1. 役割境界

動詞単位で責務を分割する。`tansaku` は情報取得 / 構造把握 / 用語整理を扱う。`sekkei` は controller として設計 / 計画 / 評価を決める (コードは触らない)。承認後の `jikkou` が計画実行 / 原因診断 / TDD 実装を扱い、レビュー / 提出は各専門 skill に渡す。TDD 実装層では `jikkou` が vertical behavior slice を切り、TDD 実装モードで 1 slice ごとに RED → GREEN → PRUNE を回す。

```mermaid
flowchart TB
  subgraph EXPLORE["tansaku（探索）"]
    T["探す<br/>code map / impact scope / terminology"]
  end
  subgraph DESIGN["sekkei（設計）"]
    K["考える・決める<br/>設計 / 評価 / 計画 (コード触らない)"]
  end
  subgraph EXEC["jikkou（実行）"]
    J["作る<br/>計画実行 / commit checkpoint / TDD 実装 (RED → GREEN → REFACTOR → PRUNE)"]
    JD["診る<br/>診断 / root cause"]
  end
  subgraph REVIEW["sadoku（査読）"]
    R["見る<br/>code / executable spec review / simplify"]
  end
  subgraph SUBMIT["teishutsu（提出）"]
    M["出す<br/>PR 本文 / committed scope / normal push / cwd-aware gh"]
  end

  T -->|"brief"| K
  K -->|"Plan 承認 / 進めて"| J
  J -->|"原因未確定"| JD
  JD -->|"root cause 確定"| J
  J -.->|"scope 逸脱 / 方針の再決定"| K
  JD -.->|"方針ごと再検討"| K
  J -->|"実装完了"| REVIEW
  REVIEW -.->|"局所修正 finding"| J
  REVIEW -.->|"設計判断 finding"| K
  REVIEW -->|"レビュー済 diff"| SUBMIT
```

---

## 2. 起動トリガーとモード切替

skill 単位の起動トリガー早見表は README の [trigger 早見表](../README.md#trigger-早見表) を参照 (各 SKILL.md frontmatter から `scripts/gen-trigger-docs.sh` が生成する)。mode 定義の正本は各 `SKILL.md`。

mode 別の起動トリガーと手順は各 `SKILL.md` の「モード表」が正本 (README の生成表は skill 単位の起動語)。ここで二重管理しない。TDD 実装の必須 / skip レイヤー判定は `../skills/jikkou/references/tdd.md` を参照。

> **状態トリガー** (git diff 検出・計画実行の完了報告直後など) の詳細は各 `SKILL.md` を参照。判断の差し込みは状態変化で行い、固定の会話回数では発火させない。reviewer コメント対応は skill mode 化しない (通常会話で「返信書いて」)。

### 起動経路は 3 層ある (運用実態)

trigger 表は「どう呼ばれうるか」の定義。実際の起動経路は skill ごとに偏りがあり、これは設計どおり:

| 経路 | 主な skill | 意味 |
|---|---|---|
| 会話内の自動ルーティング | `sekkei` / `jikkou` / `sadoku` / `teishutsu` | ユーザの発話・セッション状態から発火する主動線 |
| エージェント実行 (goal コマンド / VM など) | `jikkou` (TDD 実装モード) | 自律実行の中で TDD 実装層として使われる。ローカルの metrics には残らない |
| ユーザの明示起動 + `sekkei` からの handoff | `tansaku` | 実装前にユーザが全体像を掴みたいとき、または sekkei が判断前の情報不足で差し戻すとき (§3)。会話の自動ルーティングでの発火が少ないのは正常 |

`~/.hikizan/metrics.jsonl` が観測できるのはこのマシンの会話セッションだけ。起動回数の多寡だけで skill の要否を判断しない。

---

## 3. skill 間 handoff 表

「誰から誰へ」「きっかけ」「渡すもの」の一覧。

| from                 | to                     | きっかけ                    | 何を渡す              |
| -------------------- | ---------------------- | --------------------------- | --------------------- |
| (user)               | tansaku 探索          | 「探索して」「全体像を掴んで」 | 対象 file / dir / issue |
| tansaku 探索         | subagent (探索 scout)  | 独立領域が 3 つ以上          | sub-question + 対象範囲 |
| subagent             | tansaku                | 探索完了                    | digest（要裏取り・統合）|
| tansaku 探索         | sekkei 通常検討        | 設計判断に進める              | Map + Terminology + Unknowns + Evidence |
| sekkei 通常検討      | tansaku 探索          | 判断前の情報不足              | 要望 / 対象 file / 既知 evidence |
| (user)               | sekkei 通常検討        | 「設計どうする」            | issue + DoD / tansaku brief |
| (user)               | sekkei 軽量検討        | 「どうやって直す」          | 修正対象              |
| sekkei 軽量検討      | jikkou 計画実行        | 1-step plan承認            | change + file + verification + owner skill |
| (user)               | sekkei 評価            | 「やる価値ある」            | 判断対象              |
| (user)               | jikkou 診断       | 「エラー」「動かない」      | バグ症状              |
| sekkei 通常検討      | jikkou 計画実行        | Plan 承認 / 「進めて」      | owner skill付きPlan steps + ADR候補 (任意) |
| jikkou 計画実行      | sekkei 通常検討        | scope 逸脱 / 方針の再決定   | 逸脱点 + 再検討したい判断 |
| jikkou 計画実行      | jikkou 診断       | 原因未確定 / test failure   | 症状 + evidence |
| jikkou 診断     | jikkou 計画実行        | root cause 確定             | root cause 1 文 + fix 候補 |
| jikkou 計画実行      | sadoku 通常レビュー    | 実装完了                    | 1行handoff (observable behavior + 固有判断 / risk + review descriptor) + 報告 / 完成diff / 検証出力 |
| (user)               | sadoku 通常レビュー    | 「レビューして」            | diff / code範囲 / 実行仕様Markdown |
| sadoku 通常レビュー  | subagent (reviewer-*)  | Standard以上のproduction artifact / 専門観点該当 | 対象 + 近隣の比較対象 + repo conventionの出典 + 設計前提 |
| subagent             | sadoku                 | 評価完了                    | findings（要裏取り）  |
| (user)               | sadoku simplify findings | 「整理して」「simplify」(明示) | diff (範囲)        |
| sadoku simplify findings | jikkou 計画実行    | simplify finding (high)     | 対象 finding + file:line |
| sadoku 通常レビュー  | sekkei 通常検討        | module境界・方針変更が必要なfinding | finding + evidence + owner skill |
| (user)               | teishutsu              | 「PR出す」「PR提出」        | 実装完了 + commit 済み diff       |
| jikkou 計画実行      | teishutsu              | 完了報告 + 本文準備済       | commit 済み diff + files changed + body  |
| (user)               | teishutsu              | 「PR文書いて」              | change intent + files + verification |

`jikkou`は必要な意味的checkpointをcommitとして保存する。ADRは`sekkei`が候補のpath / decision / 理由をplanへ置き、userが承認したstepだけ`jikkou`がfileへ書く。`teishutsu`はcommitを作らず、commit済みscopeの通常pushとPR作成だけを行う。提出モードの承認範囲と停止条件の正本は`skills/teishutsu/SKILL.md`に置く。本文ドラフトモードは書き込みを行わない。

handoff の共通形 (1 行):

```text
handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]
```

---

## 4. Goal loop で使う場合

Claude Code / Codex などの runtime が `/goal` 相当の継続実行機能を持つ場合、hikizan は loop engine ではなく loop 内の判断規約として使う。hikizan の skill / hook は次 turn を自動発火せず、会話回数も数えない。skill 間の受け渡しは §3 の handoff 表のとおり。

Example goal:

```text
この issue を完了まで進める。未知領域や用語ズレがあれば `tansaku`、設計・計画は `sekkei`、承認後の実行 controller は `jikkou`、TDD 実装は `jikkou` の TDD 実装モード、実装後レビューは `sadoku`、提出は `teishutsu` に渡す。各 step で検証ログを残し、失敗時は `jikkou 診断` に戻る。
```

---

## 5. 検証ログの原則

各skillのmode / stop / handoffと、最後に添える報告envelopeは該当`SKILL.md`が正本。referenceはmode固有のprimary artifact (通常検討plan等)の詳細を定義してよいが、同じenvelopeを再定義しない。共通の原則は1つ:

**不可:** self-report だけ（「pass しました」「直りました」等）。機械的に検証できる項目は command 実行結果をそのまま引用する (設計原則「評価は環境変化で見る」、どの tier でも省略しない)。

hook の発火条件と既知の限界は `../hooks/conditions.md` (SoT)、検証の単一入口は `bash scripts/check-all.sh`。

---

*Cursor のプレビューで Mermaid が描画されないときは、拡張機能「Markdown Preview Mermaid Support」等を使う。*
