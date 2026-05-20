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
- **CLAUDE.md template** は `templates/CLAUDE.md` (SessionStart hook が冪等 bootstrap する)
- **配置** は (a) Claude Code plugin (`/plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git` + `/plugin install hikizan@hikizan`) または (b) Agent Skills CLI (`npx skills add github:hayashiii-ghub/hikizan`) の 2 経路。Codex 連携は OpenAI 公式の [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)、LSP 連携は CC 公式 marketplace の `typescript-lsp` / `pyright-lsp` / `rust-analyzer-lsp` を別途 install する設計 (hikizan 側で adapter / .lsp.json は持たない)

## このリポジトリでの作業ルール

1. skill 本体 (`skills/`) はハーネス agnostic に書く。Claude Code / Cursor / Codex 等の固有 API 名は本文に出さない (出す場合は注釈で明示)
2. PR 粒度: 1 issue = 1 PR (hikizan 自身の `sadoku` の停止条件と同じ)
3. ドキュメントは引き算原則に従う: 選択肢提示 + 推奨度 N/10 + 1 行根拠 / 図優先
4. skill discovery は frontmatter `description` を SoT にする。`when_to_use` は非標準の補助メモとして短く残すだけで、同義語を網羅しない
5. skill 間の連携は `kouchiku` を controller、`tansaku` / `shiken` / `sadoku` を discipline owner、`teishutsu` を PR 提出フローの担当とし、handoff block で渡す
6. agent の応答は問い合わせ言語に合わせる。日本語の問い合わせには自然文 (説明 / 要約 / 提案理由 / 質問) を日本語で返す (skill 内の英語 label と技術用語はそのまま残す)
7. 命名規約 (PR / branch / step の連番禁止、重複時のみ `-v2` サフィックス) に従う。正本は `skills/kouchiku/SKILL.md` の Hard Rules

## SoT マップ

ルールは下表の 1 箇所だけを正本 (SoT) とし、他ファイルは参照に留める (重複転記しない)。

| ルール | SoT |
|---|---|
| skill 発動 trigger | 各 `skills/<name>/SKILL.md` の frontmatter `description` |
| 各 skill の mode 定義 | 各 `skills/<name>/SKILL.md` の モード切替 |
| skill 間 handoff (流れ・block 形式) | `docs/workflow.md` §7 |
| 引き算原則 (推奨度 N/10 / 3 案禁止 / Minimal Approach) | `skills/kouchiku/references/minimal-approach.md` |
| 命名規約 (連番禁止 / `-v2` サフィックス) | `skills/kouchiku/SKILL.md` Hard Rules |
| 自然な日本語 (中国語起源語の言い換え) | AGENTS.md §記述ルール (下記) |
| hook 発火条件マトリクス | `hooks/conditions.md` |
| 設計原則 (charter) | `README.md` §設計原則 |

`templates/CLAUDE.md` は利用者の常時ロード context として一部ルール (命名 / remote 操作) を再掲するが、これは意図的な派生コピー。挙動を変えるときは上表の SoT を編集する。

設計原則を skill 本文から参照するときは番号でなく**名前**で書く (`§3.8` のような番号体系は doc 改訂で陳腐化する)。

## 記述ルール

skill 本文 / ドキュメントを書くときは中国語起源の表現を避け、自然な日本語にする。

| 使わない | 使う |
|---|---|
| 起草 | ドラフト / 下書き |
| 最小一歩 | 最小ステップ |
| 押し戻し | 反論 / 差し戻し |

「横展開」は IT 業界で定着しているため使用可。

## このリポジトリを使う AI agent への指示

- README.md を最初に読む
- `bin/wt` は git worktree CLI、hikizan に同梱の補助ツール
- skill の発動 trigger は下記 §skill の発動 trigger を参照、詳細仕様は各 SKILL.md

## skill の発動 trigger

各 skill の発動 trigger は frontmatter `description` が SoT。発話 trigger と mode 切替の一覧は `docs/workflow.md` §6、quick reference は `README.md` の trigger 早見表を参照。

**注**: reviewer コメントへの返信文ドラフトは skill mode 化していない (通常会話で `返信書いて` / `反論したい` のように直接依頼)。実装が必要な指摘は `kouchiku` の計画実行モードに振る。

## ライセンス

MIT (`LICENSE` 参照)
