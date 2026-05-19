---
title: Skill ワークフロー例（v4）
description: sadoku / kouchiku / tansaku / shiken / teishutsu の境界と典型フロー、hook 安全網
---

# Skill ワークフロー例

> **目的:** 「ユーザーがこう書くと、skill がこう振る舞う」を視覚的に追いやすくする。

---

## 目次

1. [役割境界](#1-役割境界)
2. [典型ワークフロー A: 新機能実装](#2-典型ワークフロー-a-新機能実装)
3. [典型ワークフロー B: バグ修正](#3-典型ワークフロー-b-バグ修正)
4. [典型ワークフロー C: 設計判断のみ](#4-典型ワークフロー-c-設計判断のみ)
5. [典型ワークフロー D: 小さい修正](#5-典型ワークフロー-d-小さい修正-軽量検討)
6. [各 skill のモード切替](#6-各-skill-のモード切替フロー)
7. [skill 間 handoff 表](#7-skill-間-handoff-表)
8. [hook 安全網](#8-hook-安全網)
9. [NG パターン](#9-ng-パターンやらないことの図解)
10. [検証ログ要件](#10-各-skill-の検証ログ要件環境変化評価)
11. [参照](#11-参照)

---

## 1. 役割境界

動詞単位で 5 分割。`kouchiku` は controller として handoff 先を選ぶが、原因調査 / TDD / レビュー / 提出の discipline は各専門 skill に渡す。

```mermaid
flowchart TB
  subgraph BUILD["kouchiku（構築）"]
    K["考える・作る<br/>設計 / 評価 / 計画 + 計画実行"]
  end
  subgraph TEST["shiken（試験）"]
    S["試す<br/>RED → GREEN → REFACTOR → PRUNE"]
  end
  subgraph REVIEW["sadoku（査読）"]
    R["見る・書く<br/>code review / PR 説明文"]
  end
  subgraph HUNT["tansaku（探索）"]
    T["追う<br/>バグ調査 / root cause"]
  end
  subgraph SUBMIT["teishutsu（提出）"]
    M["出す<br/>remote / submodule / parent / cwd-aware gh"]
  end

  BUILD -->|"原因未確定"| HUNT
  HUNT -->|"root cause 確定"| TEST
  HUNT -.->|"調査結果"| BUILD
  BUILD -->|"TDD 必要層"| TEST
  TEST -->|"検証ログ付き return"| BUILD
  BUILD -->|"実装完了"| REVIEW
  REVIEW -.->|"simplify finding<br/>(high severity)"| BUILD
  REVIEW -->|"PR 本文 ok"| SUBMIT
  SUBMIT -.->|"PR 本文未準備"| REVIEW
```

### skill 一覧

| skill     | 漢字 | 動詞       | 担当                                       |
| --------- | ---- | ---------- | ------------------------------------------ |
| sadoku    | 査読 | 見る・書く | code review / PR 説明文                  |
| kouchiku  | 構築 | 考える・作る | 設計判断 / 評価 / 計画策定 / 計画実行   |
| tansaku   | 探索 | 追う       | バグ調査 / root cause investigation       |
| shiken    | 試験 | 試す       | TDD discipline / PRUNE                     |
| teishutsu | 提出 | 出す       | PR 提出 (remote / submodule / parent / cwd-aware gh) |

---

## 2. 典型ワークフロー A: 新機能実装

issue 受領から PR 出荷まで。**kouchiku** が controller として計画を持ち、必要な局面で専門 skill に handoff する。

```mermaid
flowchart TB
  A["issue + DoD"] -->|"設計どうする"| B["kouchiku 通常検討<br/>問題定義・案・前提崩し・攻撃検証・Plan"]
  B -->|"Plan 承認 / 進めて"| C["kouchiku 計画実行<br/>owner skill 付き Plan steps"]
  C -->|"原因未確定"| I["tansaku<br/>root cause 1文 + evidence"]
  I -->|"調査結果 return"| C
  C -->|"TDD 必要層"| D["shiken<br/>RED → GREEN → REFACTOR → PRUNE"]
  D -->|"検証ログ付き return"| C
  C -->|"handoff block"| E["sadoku 通常レビュー<br/>深さ・停止条件・完了記録"]
  E -->|"Standard 以上"| F["専門家レビュー<br/>subagent 並列最大3<br/>security / arch / adversarial は inline"]
  F -->|"裏取り済み反映"| G["sadoku PR 説明文<br/>pr-template 8 step"]
  G -->|"PII scan / 4 チェック"| H["teishutsu<br/>remote / submodule / parent / cwd-aware gh"]
  H -->|"hook で衝突なし"| J["PR open"]
```

> **ポイント**
>
> - **kouchiku → tansaku / shiken → kouchiku** の往復は handoff block で起こる。
> - **sadoku** は実装完了後に初めて起動（「見る」専門）。
> - **専門家レビュー**は Standard 以上のみ。Quick は停止条件中心。

<details>
<summary>ASCII 版（コピー用）</summary>

```
                    ┌──────────────────┐
                    │     kouchiku     │
                    │       構築        │
                    └────┬─────────┬───┘
                         │         │
                  TDD 必要層     実装完了
                         ▼         ▼
                  ┌──────────┐  ┌──────────────┐
                  │  shiken  │  │    sadoku    │
                  └──────────┘  └──────────────┘
                  ┌──────────┐
                  │ tansaku  │
                  └──────────┘
```

</details>

---

## 3. 典型ワークフロー B: バグ修正

バグ報告から **regression guard** 付き PR まで。

```mermaid
flowchart TB
  B0["バグ報告 / error / 動かない"] --> B1["tansaku 通常追跡<br/>症状列挙・hypothesis 1文・instrument 1つ・confirm/fix"]
  B1 -->|"root cause 確定<br/>fix 前"| B2["shiken regression guard<br/>RED: 実装前は fail<br/>GREEN: fix 後 pass<br/>PRUNE: revert で fail 目視"]
  B2 --> B3["sadoku 通常レビュー + PR 説明文"]
  B3 --> B4["teishutsu"]
  B4 --> B5["PR open"]
```

> **ポイント**
>
> - **tansaku**: hypothesis を 1 文にできるまでコードに触らない discipline。
> - **bugfix** は shiken の**強制**層。再現テストを先行。
> - 「直りました」だけは不可。**fix 前後の挙動差分をそのまま引用**。

---

## 4. 典型ワークフロー C: 設計判断のみ

判断要求 → verdict。**コードは触らない。**

```mermaid
flowchart TB
  C0["kill か keep か / やる価値ある?"] --> C1["kouchiku 評価<br/>Verdict: Kill / Keep / Pivot<br/>理由3つ（user 制約ベース）"]
```

| ルール                         | 内容                                       |
| ------------------------------ | ------------------------------------------ |
| 「保留」は出さない             | 判断回避にならないようにする               |
| 技術的好みだけで決めない       | user 制約を根拠に含める                    |

---

## 5. 典型ワークフロー D: 小さい修正（軽量検討）

**変更対象が概ね 3 ファイル未満**の即決パターン。

```mermaid
flowchart TB
  D0["どうやって直す / やり方どっち"] --> D1["kouchiku 軽量検討<br/>推奨案・brute 案・risk"]
  D1 -->|"案選択 / 計画実行"| D2["kouchiku 計画実行<br/>（TDD 必要なら shiken）"]
  D2 --> D3["sadoku 通常レビュー Quick<br/>停止条件のみ・〜50行想定"]
  D3 --> D4["teishutsu"]
  D4 --> D5["PR open"]
```

---

## 6. 各 skill のモード切替フロー

### sadoku

| 種類           | trigger の例                                                          | 遷移先                              |
| -------------- | --------------------------------------------------------------------- | ----------------------------------- |
| ユーザー発話   | 「レビューして」                                                       | 通常レビュー                        |
| ユーザー発話   | 「整理して」「simplify」「整理ポイントある?」「スリム化したい」          | simplify findings                   |
| ユーザー発話   | 「コードレビュー」「コードレビューして」(compound)                     | 通常レビュー → simplify findings    |
| ユーザー発話   | 「PR文書いて」「PR description」                                       | PR 説明文                           |
| 状態           | git diff 検出 → 「レビューしますか?」                                  | 通常レビュー                        |
| 状態           | PR open 直前                                                          | 確認 prompt                         |

> reviewer コメント対応は **skill のモードにしない**。通常会話で「返信書いて」と頼む形。

### kouchiku

| trigger の例                                               | 遷移先     |
| ---------------------------------------------------------- | ---------- |
| 「どうやって直す」「やり方どっち」                         | 軽量検討   |
| 「設計どうする」「方針決めたい」「アーキテクチャ判断」     | 通常検討   |
| 「やる価値ある」「採用すべきか」「kill か keep」「やめる?」 | 評価       |
| 「計画実行」「進めて」「着手」「実装開始」（承認直後）     | 計画実行   |

### tansaku

| trigger の例                                       | 遷移先     |
| -------------------------------------------------- | ---------- |
| 「エラー」「動かない」「落ちる」「クラッシュ」     | 通常追跡   |
| 「前は動いてた」「アップデート後」「更新後動かない」 | 二分探索   |
| 「同じ問題が再発」                                 | 再発追跡   |
| 「good」screenshot 添付                            | 再発追跡   |

### shiken

| trigger の例                         | 遷移先   |
| ------------------------------------ | -------- |
| 「TDDで」「テストから書いて」        | 起動     |
| 純ロジック / API / バグ修正に触れる  | **強制** |
| インタラクションに触れる             | 推奨     |
| 純スタイル / アニメ / 文言のみ       | スキップ可（理由必須） |

### teishutsu

| trigger の例                                            | 遷移先 |
| ------------------------------------------------------- | ------ |
| 「PR出す」「PR提出」「PR ready」「提出して」            | 起動   |
| `kouchiku` 計画実行モードの完了報告直後                  | 起動   |

---

## 7. skill 間 handoff 表

「誰から誰へ」「きっかけ」「渡すもの」を一括で見る図。矢印ラベルは **上段＝きっかけ / 下段＝渡すもの**。

```mermaid
flowchart TB
  U["user"]

  subgraph KC["kouchiku（構築）"]
    direction TB
    KT["通常検討"]
    KK["軽量検討"]
    KH["評価"]
    KJ["計画実行"]
  end

  SH["shiken（試験）"]

  subgraph SD["sadoku（査読）"]
    direction TB
    SR["通常レビュー"]
    SS["simplify findings"]
    SPR["PR 説明文"]
  end

  SUB["subagent<br/>reviewer-*"]
  TA["tansaku（探索）"]
  TS["teishutsu（提出）"]

  U -->|"設計どうする<br/>────────<br/>issue + DoD"| KT
  U -->|"どうやって直す<br/>────────<br/>修正対象"| KK
  U -->|"やる価値ある<br/>────────<br/>判断対象"| KH

  KK -.->|"案確定後<br/>進めて"| KJ
  KH -.->|"判断後<br/>実装へ"| KJ

  KT -->|"計画実行 / 進めて<br/>────────<br/>Plan steps"| KJ

  KJ -->|"TDD 必要層に触れた<br/>────────<br/>レイヤー判定 + コード"| SH
  SH -->|"サイクル完了<br/>────────<br/>green 状態のコード"| KJ

  KJ -->|"実装完了<br/>────────<br/>完成 diff"| SR

  U -->|"レビューして<br/>────────<br/>diff"| SR
  U -->|"整理して / simplify<br/>────────<br/>diff (範囲)"| SS
  U -->|"コードレビュー (compound)<br/>────────<br/>diff"| SR
  SR -.->|"compound 起動時<br/>────────<br/>レビュー後に連結"| SS
  SS -->|"simplify finding (high)<br/>────────<br/>対象 finding + file:line"| KJ

  SR -->|"gate (b)<br/>────────<br/>diff + 範囲"| SUB
  SUB -->|"評価完了<br/>────────<br/>findings（要裏取り）"| SR

  SR -->|"PR文書いて<br/>────────<br/>レビュー済 diff + scope"| SPR

  U -->|"エラー / 動かない<br/>────────<br/>バグ症状"| TA
  TA -->|"bugfix 確定<br/>────────<br/>regression guard 要件"| SH

  U -->|"PR出す / PR提出<br/>────────<br/>実装完了 + diff"| TS
  SPR -->|"PR 本文 ok<br/>────────<br/>レビュー済 本文 + diff"| TS
  KJ -->|"完了報告 + 本文準備済<br/>────────<br/>files changed + body"| TS
  TS -.->|"PR 本文未準備<br/>────────<br/>change intent + files + verification"| SPR
```

### 詳細（表形式）

| from                 | to                     | きっかけ                    | 何を渡す              |
| -------------------- | ---------------------- | --------------------------- | --------------------- |
| (user)               | kouchiku 通常検討      | 「設計どうする」            | issue + DoD           |
| (user)               | kouchiku 軽量検討      | 「どうやって直す」          | 修正対象              |
| (user)               | kouchiku 評価          | 「やる価値ある」            | 判断対象              |
| kouchiku 通常検討    | kouchiku 計画実行      | 「計画実行」「進めて」      | owner skill 付き Plan steps |
| kouchiku 計画実行    | tansaku                | 原因未確定 / test failure   | 症状 + evidence + expected return |
| tansaku              | kouchiku 計画実行      | root cause 確定             | root cause 1 文 + fix 候補 |
| kouchiku 計画実行    | shiken                 | TDD 必要層に触れた          | spec / edge case / non-goals |
| tansaku              | shiken                 | bugfix 確定                 | root cause + failing behavior + test target |
| shiken               | kouchiku 計画実行      | サイクル完了                | RED/GREEN/PRUNE log + files changed |
| kouchiku 計画実行    | sadoku 通常レビュー    | 実装完了                    | handoff block + 完成 diff |
| (user)               | sadoku 通常レビュー    | 「レビューして」            | diff                  |
| sadoku 通常レビュー  | subagent (reviewer-*)  | gate (b)                    | diff + 範囲           |
| subagent             | sadoku                 | 評価完了                    | findings（要裏取り）  |
| sadoku 通常レビュー  | sadoku PR 説明文       | 「PR文書いて」              | レビュー済 diff + scope |
| (user)               | sadoku simplify findings | 「整理して」「simplify」  | diff (範囲)           |
| sadoku 通常レビュー  | sadoku simplify findings | compound (「コードレビュー」) | レビュー後の連結実行 |
| sadoku simplify findings | kouchiku 計画実行  | simplify finding (high)     | 対象 finding + file:line |
| (user)               | tansaku                | 「エラー」「動かない」      | バグ症状              |
| (user)               | teishutsu              | 「PR出す」「PR提出」        | 実装完了 + diff       |
| sadoku PR 説明文     | teishutsu              | PR 本文 ok                  | レビュー済 本文 + diff |
| kouchiku 計画実行    | teishutsu              | 完了報告 + 本文準備済       | files changed + body  |
| teishutsu            | sadoku PR 説明文       | PR 本文未準備               | change intent + files + verification |

handoff block の共通形:

```text
handoff: [skill]
reason: [なぜ今渡すか]
context: [症状 / 仕様 / 設計判断]
evidence:
  - [file:line / command output / logs]
expected return:
  - [戻してほしい成果物]
```

---

## 8. hook 安全網

skill 本文は「正常経路で漏れを防ぐ」、hook は「skill を経由しない経路でも止める最後の砦」。実体は `hooks/hooks.json` と `scripts/`。発火イベントは `~/.hikizan/metrics.jsonl` に記録される (`HIKIZAN_METRICS_DIR` で書き込み先変更可)。

| event                              | 条件                                                    | 挙動                                                     |
| ---------------------------------- | ------------------------------------------------------- | -------------------------------------------------------- |
| `SessionStart` (startup)           | プロジェクト直下に CLAUDE.md なし、または「## hikizan Conventions」セクション欠落 | `templates/CLAUDE.md` を冪等 bootstrap                  |
| `PreToolUse` (Bash, `git push*`)   | non-fast-forward / force push to main・master・develop | exit 2 + stderr に選択肢                                 |
| `PreToolUse` (Bash, `gh pr create*`) | `--draft` も `--reviewer` も無い                       | exit 2 + stderr に選択肢                                 |
| `PostToolUse` (Bash, `git commit*`) | submodule pointer 変更ありで submodule 未 push          | stderr warning (block しない)                            |

```mermaid
flowchart LR
  T["teishutsu<br/>(正常経路で漏れを防ぐ)"] -->|"想定外に直接 push/PR したい"| H["hook<br/>(最後の砦)"]
  T -.->|"通常は teishutsu の step が hook より先に検出"| OK["正常 path"]
  H -->|"exit 2 + 選択肢"| BACK["呼び出し元 (Claude) に差し戻し"]
```

詳細: `hooks/conditions.md`。

---

## 9. NG パターン（やらないことの図解）

### NG-1: 廃止された「レビュー咀嚼モード」を skill で済ませる

```mermaid
flowchart TB
  N1["reviewer コメント複数"] --> X1["❌ sadoku に専用 mode がある想定"]
  X1 --> OK1["✅ 通常会話<br/>返信書いて / 実装は kouchiku へ"]
```

### NG-2: TDD レイヤーを素通り

```mermaid
flowchart TB
  N2["純ロジックに新規実装"] --> X2["❌ kouchiku 計画実行だけで実装"]
  X2 --> X3["❌ sadoku で未テスト・テスト最小性違反"]
  N2 --> OK2["✅ shiken 強制層を経由"]
```

### NG-3: hypothesis なしで tansaku

```mermaid
flowchart TB
  N3["とりあえず試そう"] --> X4["❌ code 先行"]
  X4 --> BAD["instrument 過多 / root cause 不明 / 再発"]
  N3 --> OK3["✅ hypothesis 1文 → instrument 1つ"]
```

### NG-4: teishutsu を skip して直接 gh pr create

```mermaid
flowchart TB
  N4["実装完了 → 直 gh pr create"] --> X5["❌ remote 状態未確認 / submodule 順序ミス / cwd ミス"]
  X5 --> BAD2["pre-pr-create hook で block (二段目で救われるが余計な往復)"]
  N4 --> OK4["✅ teishutsu 4 step → hook は最後の砦"]
```

---

## 10. 各 skill の検証ログ要件（環境変化評価）

| skill     | 検証ログ必須項目                                                 | 形式                    |
| --------- | ---------------------------------------------------------------- | ----------------------- |
| sadoku    | 停止条件 scan / tests / verification / PII scan                  | command + 出力末尾      |
| kouchiku  | （計画実行モードのみ）verification                               | command + 出力末尾      |
| tansaku   | Confirmed（fix 前後の挙動差分）/ Tests                           | そのまま引用            |
| shiken    | RED / GREEN / PRUNE 各 phase                                     | test runner 最終行      |
| teishutsu | remote state / submodule / parent commit / push / cwd at gh / PR | command + 出力 (`pwd` はそのまま引用) |

**禁止:** self-report だけ（「pass しました」「直りました」等）。**必ず command 実行結果を引用**。

---

## 11. 参照

| 種別                         | パス                                                                              |
| ---------------------------- | --------------------------------------------------------------------------------- |
| sadoku                       | `../skills/sadoku/SKILL.md`                                                       |
| PR テンプレ                  | `../skills/sadoku/references/pr-template.md`                                      |
| persona                      | `../skills/sadoku/references/persona-catalog.md`                                  |
| 文脈抽出                     | `../skills/sadoku/references/project-context.md`                                  |
| subagent                     | `../skills/sadoku/references/agents/reviewer-security.md`, `reviewer-architecture.md` |
| kouchiku                     | `../skills/kouchiku/SKILL.md`                                                     |
| 引き算プロトコル             | `../skills/kouchiku/references/minimal-approach.md`                               |
| tansaku                      | `../skills/tansaku/SKILL.md`, `../skills/tansaku/references/logging-techniques.md` |
| shiken                       | `../skills/shiken/SKILL.md`, `../skills/shiken/references/testing-anti-patterns.md` |
| teishutsu                    | `../skills/teishutsu/SKILL.md`                                                    |
| hook 設定 / 停止条件マトリクス | `../hooks/conditions.md`, `../hooks/hooks.json`     |
| CLAUDE.md テンプレ           | `../templates/CLAUDE.md`                                                          |
| 記述ルール                   | `./style-guide.md`                                                                |

---

*Cursor のプレビューで Mermaid が描画されない場合は、拡張機能「Markdown Preview Mermaid Support」等の利用を検討してください。*
