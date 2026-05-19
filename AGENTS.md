# AGENTS.md

このリポジトリは **hikizan** — 日本語圏チーム開発向けの Claude Code plugin 兼 Agent Skills 対応 skill pack です。`.claude-plugin/` (Claude Code 経由) と `skills/` (Agent Skills CLI 経由) の 2 経路で配布します。中核に据えるのは**引き算の哲学**。

## 構成

- **skill 本体** は `skills/` 配下 (ハーネス agnostic な SoT、multi file)
  - `sadoku` (査読) — code review / PR 説明文
  - `kouchiku` (構築) — 設計判断 / 計画策定 / 計画実行
  - `tansaku` (探索) — バグ調査 / root cause investigation
  - `shiken` (試験) — TDD discipline / PRUNE
  - `teishutsu` (提出) — PR 提出フロー (リモート確認 / submodule / parent commit / cwd-aware gh)
- **使い方ガイド** は `docs/workflow.md` (mermaid 図入り)
- **配置** は (a) Claude Code plugin (`/plugin marketplace add hayashiii-ghub/hikizan` + `/plugin install hikizan`) または (b) Agent Skills CLI (`npx skills add github:hayashiii-ghub/hikizan`) の 2 経路。Codex 連携は OpenAI 公式の [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)、LSP 連携は CC 公式 marketplace の `typescript-lsp` / `pyright-lsp` / `rust-analyzer-lsp` を別途 install する設計 (hikizan 側で adapter / .lsp.json は持たない)。`adapters/` は Agent Skills 標準でカバーできない特殊ケース用の予約領域

## このリポジトリでの作業ルール

1. skill 本体 (`skills/`) はハーネス agnostic に書く。Claude Code / Cursor / Codex 等の固有 API 名は本文に出さない (出す場合は `adapters/` に隔離 or 注釈で明示)
2. PR 粒度: 1 issue = 1 PR (hikizan 自身の `sadoku` の停止条件と同じ)
3. ドキュメントは引き算原則に従う: 選択肢提示 + 推奨度 N/10 + 1 行根拠 / 図優先
4. skill discovery は frontmatter `description` を SoT にする。`when_to_use` は非標準の補助メモとして短く残すだけで、同義語を網羅しない
5. skill 間の連携は `kouchiku` を controller、`tansaku` / `shiken` / `sadoku` を discipline owner とし、handoff block で渡す
6. agent の応答は問い合わせ言語に合わせる。日本語の問い合わせには自然文 (説明 / 要約 / 提案理由 / 質問) を日本語で返す (skill 内の英語 label と技術用語はそのまま残す)
7. PR / branch / step を独自連番 (PR-1 等) で呼ばない。issue 名 / 機能名 / branch 名で呼ぶ。重複時のみ -v2, -v3 ... のサフィックスを使う

## このリポジトリを使う AI agent への指示

- README.md を最初に読む
- `bin/wt` は git worktree CLI、hikizan に同梱の補助ツール
- skill の発動 trigger は下記「skill の発動 trigger 一覧」を参照、詳細仕様は各 SKILL.md

## skill の発動 trigger 一覧

ユーザの発話に下記キーワードが含まれたら、対応する skill / mode を起動する。詳細 (停止条件 / 完了記録 / 状態 trigger / 専門家レビューなど) は各 `skills/<name>/SKILL.md` を参照。

| skill | mode | 発話 trigger |
|---|---|---|
| `sadoku` (査読) | 通常レビュー | `レビューして` |
| `sadoku` | simplify findings | `整理して` / `simplify` / `整理ポイントある?` / `スリム化したい` |
| `sadoku` | 通常レビュー + simplify (compound) | `コードレビュー` / `コードレビューして` |
| `sadoku` | PR 説明文 | `PR文書いて` / `PR description` |
| `kouchiku` (構築) | 軽量検討 | `どうやって直す` / `やり方どっち` |
| `kouchiku` | 通常検討 | `設計どうする` / `方針決めたい` / `アーキテクチャ判断` |
| `kouchiku` | 評価 | `やる価値ある` / `採用すべきか` / `kill か keep か` / `やめる?` |
| `kouchiku` | 計画実行 | `計画実行` / `進めて` / `着手` / `実装開始` |
| `tansaku` (探索) | 通常追跡 | `エラー` / `動かない` / `落ちる` / `クラッシュ` |
| `tansaku` | 二分探索 | `前は動いてた` / `アップデート後から` / `更新後動かない` |
| `tansaku` | 再発追跡 | `同じ問題が再発` |
| `shiken` (試験) | 起動 | `TDDで` / `テストから書いて` |
| `teishutsu` (提出) | 起動 | `PR出す` / `PR提出` / `PR ready` / `提出して` |

**注**: reviewer コメントへの返信文ドラフトは skill mode 化していない (通常会話で `返信書いて` / `押し戻したい` のように直接依頼)。実装が必要な指摘は `kouchiku` の計画実行モードに振る。

## ライセンス

MIT (`LICENSE` 参照)
