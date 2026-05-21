# AGENTS.md

このリポジトリは **hikizan** — 日本語圏チーム開発向けの Claude Code plugin 兼 Agent Skills 対応 skill pack です。`.claude-plugin/` (Claude Code 経由) と `skills/` (Agent Skills CLI 経由) の 2 経路で配布します。中核に据えるのは**引き算の哲学**。

## 構成

- **skill 本体** は `skills/` 配下 (ハーネス agnostic な SoT、multi file)
  - `sadoku` (査読) — code review / PR 説明文
  - `kouchiku` (構築) — 設計判断 / 計画策定 / 計画実行
  - `tansaku` (探索) — バグ調査 / root cause investigation
  - `shiken` (試験) — TDD discipline / PRUNE
  - `teishutsu` (提出) — PR 提出フロー (リモート確認 / submodule / parent commit / cwd-aware gh)
- **使い方ガイド** は `docs/workflow.md` (mermaid 図入り)。記述ルールは下記 §記述ルール
- **hooks** は `hooks/hooks.json` (SessionStart / PreToolUse / PostToolUse)、停止条件マトリクスは `hooks/conditions.md`、scripts は `hooks/scripts/`、発火ログは `~/.hikizan/metrics.jsonl`
- **CLAUDE.md template** は `templates/CLAUDE.md` (SessionStart hook が必要なセクションを重複なく追加する)
- **配置** は (a) Claude Code plugin (`/plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git` + `/plugin install hikizan@hikizan`) または (b) Agent Skills CLI (`npx skills add github:hayashiii-ghub/hikizan`) の 2 経路。Codex 連携は OpenAI 公式の [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)、LSP 連携は CC 公式 marketplace の `typescript-lsp` / `pyright-lsp` / `rust-analyzer-lsp` を別途 install する設計 (hikizan 側で adapter / .lsp.json は持たない)

## このリポジトリでの作業ルール

1. skill 本体 (`skills/`) はハーネス agnostic に書く。Claude Code / Cursor / Codex 等の固有 API 名は本文に出さない (出す場合は注釈で明示)
2. skill discovery は frontmatter `description` を SoT にする。`when_to_use` は非標準の補助メモとして短く残すだけで、同義語を網羅しない
3. agent の応答は問い合わせ言語に合わせる。日本語の問い合わせには自然文 (説明 / 要約 / 提案理由 / 質問) を日本語で返す (skill 内の英語 label と技術用語はそのまま残す)
4. `AGENTS.md` と `templates/CLAUDE.md` は trigger / routing だけに寄せる。skill の出力形式 / mode 詳細 / hook 条件は再掲しない

## ファイルの責務

| ファイル | 書くこと | 書かないこと |
|---|---|---|
| `AGENTS.md` | hikizan repo を編集する AI agent 向けの routing と記述ルール | skill / hook の挙動詳細 |
| `templates/CLAUDE.md` | 利用先 project で常時ロードする routing と safety | skill の mode 詳細、出力形式、hook の発火条件 |
| `skills/<name>/SKILL.md` | 各 skill の trigger、mode、停止条件、出力形式 | 他 skill の詳細手順 |
| `hooks/conditions.md` | hook の発火条件、挙動、終了コード | skill の通常フロー |
| `README.md` | 人間向けの概要、install、導線 | SoT の重複転記 |

## Routing

| 条件 | 見る SoT |
|---|---|
| skill を起動する条件を変える | 各 `skills/<name>/SKILL.md` の frontmatter `description` |
| skill の mode / 出力形式 / 停止条件を変える | 各 `skills/<name>/SKILL.md` |
| skill 間 handoff を変える | `docs/workflow.md` §7 |
| PR / branch / step の命名規約を変える | `skills/kouchiku/SKILL.md` Hard Rules |
| 引き算原則を変える | `skills/kouchiku/references/minimal-approach.md` |
| review / PR 説明文 / 整理観点を変える | `skills/sadoku/SKILL.md` |
| PR 提出フローを変える | `skills/teishutsu/SKILL.md` |
| hook の発火条件や block / warning を変える | `hooks/conditions.md` と `hooks/hooks.json` |
| 利用先 project に常時読ませる最小 routing を変える | `templates/CLAUDE.md` |
| 自然な日本語の言い換えを変える | AGENTS.md §記述ルール |
| 設計原則を変える | `README.md` §設計原則 |

`templates/CLAUDE.md` は利用者の常時ロード context として routing と safety だけを持つ。挙動を変えるときは上表の SoT を編集する。

設計原則を skill 本文から参照するときは番号でなく**名前**で書く (`§3.8` のような番号体系は doc 改訂で陳腐化する)。

## 記述ルール

skill 本文 / ドキュメントを書くときは中国語起源の表現を避け、自然な日本語にする。

| 使わない | 使う |
|---|---|
| 起草 | ドラフト / 下書き |
| 最小一歩 | 最小ステップ |
| 押し戻し | 反論 / 差し戻し |

「横展開」は IT 業界で定着しているため使用可。

レビュー前の軽い機械確認として `bin/check-terms` を走らせる。上表の正本である `AGENTS.md` と確認スクリプト自身は検索対象から外す。

## このリポジトリを使う AI agent への指示

- README.md を最初に読む
- `bin/wt` は git worktree CLI、hikizan に同梱の補助ツール
- `bin/check-terms` はドキュメントの避けたい表現を検出する軽い確認スクリプト
- skill の発動 trigger は下記 §skill の発動 trigger を参照、詳細仕様は各 SKILL.md

## skill の発動 trigger

各 skill の発動 trigger は frontmatter `description` が SoT。発話 trigger と mode 切替の一覧は `docs/workflow.md` §6、quick reference は `README.md` の trigger 早見表を参照。

**注**: reviewer コメントへの返信文ドラフトは skill mode 化していない (通常会話で `返信書いて` / `反論したい` のように直接依頼)。実装が必要な指摘は `kouchiku` の計画実行モードに振る。

## ライセンス

MIT (`LICENSE` 参照)
