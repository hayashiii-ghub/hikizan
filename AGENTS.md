# AGENTS.md

## Overview

この repo は **hikizan** plugin / skill pack 本体。shell + markdown のみで package manager / build step は無い。ランタイム本体は `hooks/scripts/` の bash hook 群と `skills/` の SKILL.md 群。作業時はこのファイルを入口にし、詳細は [Routing](#routing) の SoT に従う。

## Setup

依存は `bash` / `jq` / `git` / `gh` / `awk` のみ (Cursor Cloud 等の VM base image に既にある。update script でインストールするものは無い)。開発中の plugin は `claude --plugin-dir <repo root>` で Claude Code に直接読み込める。

## Test

検証の単一入口は `bash scripts/check-all.sh` (hook tests + consistency lint + trigger 表鮮度)。提出前に回す。CI (`.github/workflows/ci.yml`) も同じ 1 コマンドを回す。

hook を単体で動かすときの gotcha:

- PreToolUse hook は JSON payload を stdin に流す (例 `printf '{"tool_input":{"command":"git push --force origin main"},"cwd":"/workspace"}' | bash hooks/scripts/pre-push.sh`)。発火条件の正本は `hooks/conditions.md`。
- `session-context.sh` は `CLAUDE_PLUGIN_ROOT` が未設定だと template を読めず no-op になる。単体実行時は `CLAUDE_PLUGIN_ROOT=<repo root>` を渡す。
- hook は発火を `~/.hikizan/metrics.jsonl` に追記する。単体で試すときは `HIKIZAN_METRICS_DIR` を temp dir に向けて実データを汚さない。
- `hooks/tests/e2e/bench.sh` は `claude` CLI 必須の user-run ベンチで `run.sh` / CI には含まれない。
- 決定論ロジック (hook scripts) を変えたら `hooks/tests/` を RED → GREEN で更新する。

## Conventions

- skill 本体 (`skills/`) はハーネス agnostic に書く。Claude Code / Cursor / Codex 等の固有 API 名は、必要な注釈以外では本文に出さない。
- `when_to_use` は CC 公式 frontmatter フィールド (`description` と合算で文字数上限に載るため短く保つ)。発動条件の正本は `description`。
- **trigger 早見表は手動転記しない**。`README.md` / `docs/workflow.md` の `<!-- hikizan:triggers -->` 区間は `scripts/gen-trigger-docs.sh` が frontmatter から生成する。`description` / `when_to_use` を変えたら `bash scripts/gen-trigger-docs.sh` を再実行し、`bash scripts/check-all.sh` で検証する。
- `AGENTS.md` / `templates/CLAUDE.md` に skill の手順、出力形式、hook 条件を再掲しない。
- 設計原則を skill 本文から参照するときは番号でなく名前で書く。
- 識別子は `docs/naming.md`、日本語散文は `docs/writing-style.md` に従う。

## Safety

- 破壊的操作や force push は、ユーザの明示確認なしに進めない (skill の共通ルール + hooks の floors で二重化)。
- PR 本文・commit message に秘密情報 (token / email / チーム外の実名) を書かない。出す前に grep で確認する (recipe は `skills/teishutsu/references/pr-template.md`)。

## Routing

| やること | SoT |
| --- | --- |
| skill の trigger / mode / 出力形式 / 停止条件を変える | `skills/<name>/SKILL.md` |
| skill discovery の条件を変える | 各 `skills/<name>/SKILL.md` の frontmatter `description` |
| core 7 skill 共通のルール (不可逆操作の確認 / 検証ログ引用 / 秘密情報 / 命名 / handoff 形式) を変える | 各 SKILL.md の `共通ルール` block (7 skill で同一、`scripts/check-consistency.sh` が検査) |
| 探索 / 用語整理 / 影響範囲把握を変える | `skills/tansaku/SKILL.md` |
| ドメイン文脈 (用語 / 不変条件 / 制約 / 受容済みリスク) の正本 CONTEXT.md の契約を変える | `skills/tansaku/references/context-doc.md` |
| 設計判断 / 計画立案 / kill・keep 評価を変える | `skills/sekkei/SKILL.md` |
| 計画実行 / 原因診断を変える | `skills/jikkou/SKILL.md` |
| 引き算原則を変える | `skills/sekkei/references/minimal-approach.md` |
| review / 整理観点を変える | `skills/sadoku/SKILL.md` |
| 専門家レビュー subagent を変える | `agents/reviewer-*.md` (正)、`skills/sadoku/references/agents/*` (fallback、同一内容) |
| PR 本文ドラフト / PR 提出フローを変える | `skills/teishutsu/SKILL.md` |
| hook の block / warning 条件を変える | `hooks/conditions.md` と `hooks/hooks.json` (ロジックは `hooks/scripts/lib/`、検査は `hooks/tests/`) |
| 利用先 project に注入する routing / ルール文を変える | `templates/CLAUDE.md` (注入 `session-context.sh` と `/hikizan:init` の単一ソース) |
| standard tier への opt-out 前文 (手順自由・出口固定) を変える | `templates/standard-preamble.md` (`session-context.sh` が tier=standard のときだけ注入) |
| 設計原則を変える | `docs/principles.md` |
| 人間向け説明 / install / 公開情報を変える | `README.md` |
| 他 project へ配る AGENTS.md の形式 / README の役割境界を変える | `docs/doc-format.md` (正本) と `templates/AGENTS.md` (スケルトン) |
