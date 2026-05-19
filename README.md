# hikizan

日本語圏チーム開発向けの Claude Code plugin / Agent Skills 対応 skill pack + git worktree CLI。tw93/Waza を起点に、SP (anthropic/superpowers) から選択的に取り込み、日本語圏 team-dev に最適化した **core 4 skill** と、並列開発を支える **`wt`** (worktree manager) を含む。

動詞単位で責務を分けた 5 skill (sadoku / kouchiku / tansaku / shiken / teishutsu) と **引き算の哲学**を中核に据える。

- repo: <https://github.com/hayashiii-ghub/hikizan>
- license: MIT

## core 5 skill

| skill | 漢字 | 動詞 | 担当 |
|---|---|---|---|
| `sadoku` | 査読 | 見る・書く | code review / PR 説明文 |
| `kouchiku` | 構築 | 考える・作る | 設計判断 / 評価 / 計画策定 / 計画実行 |
| `tansaku` | 探索 | 追う | バグ調査 / root cause investigation |
| `shiken` | 試験 | 試す | TDD discipline / PRUNE |
| `teishutsu` | 提出 | 出す | PR 提出フロー (remote / submodule / parent commit / cwd-aware gh) |

動詞で 5 分割した役割境界が原則。`kouchiku` は controller として設計から計画実行までを持ち、原因調査は `tansaku`、TDD discipline は `shiken`、レビュー / PR 文ドラフトは `sadoku`、PR 提出プロセスは `teishutsu` に handoff block で渡す。

## install (Claude Code plugin)

Claude Code 利用者は `/plugin` 経由が推奨経路。

```bash
# Claude Code セッション内で実行
/plugin marketplace add hayashiii-ghub/hikizan
/plugin install hikizan
```

開発・検証時は `--plugin-dir` で直接読み込み:

```bash
git clone https://github.com/hayashiii-ghub/hikizan
claude --plugin-dir ./hikizan
```

skill 名は namespace 規約により `/hikizan:sadoku` / `/hikizan:kouchiku` / `/hikizan:tansaku` / `/hikizan:shiken` / `/hikizan:teishutsu` で呼ばれる。

## install (skill pack)

hikizan は [Agent Skills 標準](https://agentskills.io) にも沿った **skill pack** です。skills-compatible agent (Cursor / Codex / Claude Code) へ `skills` CLI で配置できます。

### 推奨: `npx skills add` (1 コマンドで自動配置)

ハーネス別の例:

```bash
# Cursor
npx skills add github:hayashiii-ghub/hikizan -g -a cursor

# Claude Code
npx skills add github:hayashiii-ghub/hikizan -g -a claude-code

# Codex
npx skills add github:hayashiii-ghub/hikizan -g -a codex
```

`-g` で global (home dir)、省略時は cwd の project local。`-a` 無しだと現在のハーネスを auto-detect。詳細は [vercel-labs/skills](https://github.com/vercel-labs/skills) 参照。

### 配置の仕組み (2 段構造)

`skills` CLI は **canonical store + agent symlink** の 2 段で配置する:

```
~/.agents/skills/<skill>/   ← 実体 (canonical store, 全 agent 共通)
~/.<agent>/skills/<skill>   ← canonical への symlink (各 agent が読む)
```

Cursor は `~/.cursor/skills/`、Claude Code は `~/.claude/skills/` を auto-discovery 対象にする。`~/.agents/skills/` のみ読むのは Cline / OpenCode 等 universal 系。

### 手動配置 (npx を使わない場合)

`skills/<name>/` を各ツールの skills dir にコピー or symlink:

| ツール | path |
|---|---|
| Cursor | `~/.cursor/skills/` (global) または `./.cursor/skills/` (project) |
| Claude Code | `~/.claude/skills/` (global) または `./.claude/skills/` (project) |
| Cline / OpenCode 等 universal | `~/.agents/skills/` または `./.agents/skills/` |

waza の `kakunin` / `kentou` / `tsuiseki` 等とは skill 名が違うので衝突せず共存可能。

## install (wt — git worktree CLI)

並列開発で worktree を扱うための CLI。skill とは独立、bash 単体。

```bash
# symlink (推奨)
mkdir -p ~/.local/bin
ln -s "$(pwd)/bin/wt" ~/.local/bin/wt

# PATH に ~/.local/bin が無ければ追加
export PATH="$HOME/.local/bin:$PATH"

wt help
```

### 使い方の例

```bash
wt new feat-A             # .worktrees/feat-A/ 作成 + branch 切り
wt ls                     # 全 worktree 一覧
wt status feat-A          # 詳細
wt rm feat-A              # 削除 (未 commit / 未 push があると拒否)
wt cleanup --dry-run      # merged 済 worktree の削除候補
cd "$(wt enter feat-A)"   # worktree に cd
wt new feat-B --launch claude  # 作成して Claude を起動
```

`.worktrees/` は repo 内に作られるので、 `.gitignore` に追加するのを推奨 (hikizan 自身は既に追加済)。

## quick start (30 秒)

install + 最初の発話 1 つで動く状態にする手順。

1. install (Cursor の場合):

   ```bash
   npx skills add github:hayashiii-ghub/hikizan -g -a cursor
   ```

   Claude Code は `-a claude-code`、Codex は `-a codex` 等に差し替え。詳細は [install (skill pack)](#install-skill-pack) 参照。

2. agent を起動して発話:

   ```
   コードレビューして
   ```

   → `sadoku` が起動して review が走る。

3. 他の trigger は下の [trigger 早見表](#trigger-早見表) を参照。

## trigger 早見表

install 後、各 skill は発話で起動する。

```
"設計どうする"           → kouchiku 通常検討
"計画実行" / "進めて"     → kouchiku 計画実行
"レビューして"           → sadoku 通常レビュー
"整理して" / "simplify"   → sadoku simplify findings
"コードレビュー"          → sadoku 通常レビュー + simplify (compound)
"PR文書いて"            → sadoku PR 説明文
"エラー" / "動かない"     → tansaku 通常追跡
"TDDで" / "テストから書いて" → shiken
"PR出す" / "PR提出"     → teishutsu
```

詳しい trigger 一覧と mode 切替は `docs/workflow.md` (mermaid 図入り) を参照。

## 設計原則

1. **waza 哲学の継承**: 1 skill 多 mode、references 分離、scripts で決定論的処理
2. **Controller Owns Information**: 情報取得目的の subagent は default で使わない
3. **Inline default + subagent 明示 gate**: subagent は (a) 重い情報取得 / (b) Specialist review / (c) 機械 fan-out の 3 条件のみ
4. **SP から選択的取り込み**: Announce-at-start / worktree Step 0 検出 / Hard Rules 冒頭の 1 文ガード。Iron Law / Red Flags / Rationalization 表は不採用
5. **日本語圏最適化**: skill name は英語短語、本文は日本語、固有名詞 (TDD, mock, RED/GREEN/REFACTOR/PRUNE 等) は英語残し
6. **評価は「環境変化」で見る**: 完了記録の機械検証可能項目は command 出力をそのまま引用、自己申告は禁止
7. **散文は「伝わりやすさ」のみ**: 4 チェック (結論先出し / 1 段落 1 主張 / 読み手語彙 / 儀礼削除)
8. **引き算 (認知負荷削減)**: 選択肢提示 + 推奨度 N/10 + 1 行根拠 / 図優先 / 読み手の負荷を最優先。hikizan の他原則 (PR 粒度・テスト最小化) と同じ「引き算」哲学を全 skill に貫通させる
9. **工数はトークンベース**: 判断軸を「行数 / 人間時間」から「token 消費 / context 占有 / API コスト」に切り替え。実行者は AI agent 前提
10. **ファクトチェック**: 知識カットオフ後 / 不確実な事実は利用可能な検索・fetch・一次ソースで裏取りしてから断定

## ディレクトリ構成

```
hikizan/
├── README.md                    ← この入口 (人間中心、GitHub で最初に表示)
├── AGENTS.md                    ← AI agent 入口 + Working Agreements + skill trigger 表
├── LICENSE                      ← MIT
├── .gitignore
├── .claude-plugin/              ← Claude Code plugin manifest (CC 経由配布用)
│   └── plugin.json
├── bin/
│   └── wt                       ← git worktree CLI (bash)
├── skills/                      ← skill 本体 (SoT、CC plugin / npx skills add の両経路で読まれる)
│   ├── sadoku/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── pr-template.md
│   │       ├── project-context.md
│   │       ├── persona-catalog.md
│   │       ├── simplify-checklist.md
│   │       └── agents/
│   │           ├── reviewer-security.md
│   │           └── reviewer-architecture.md
│   ├── kouchiku/
│   │   ├── SKILL.md
│   │   └── references/minimal-approach.md
│   ├── tansaku/
│   │   ├── SKILL.md
│   │   └── references/logging-techniques.md
│   ├── shiken/
│   │   ├── SKILL.md
│   │   └── references/testing-anti-patterns.md
│   └── teishutsu/
│       └── SKILL.md
├── adapters/                    ← Codex adapter (adapters/codex/) 等、Agent Skills 標準でカバーできない特殊ケース用
│   └── README.md
└── docs/
    ├── workflow.md              ← 使い方ガイド (利用者向け、mermaid 図入り)
    └── style-guide.md           ← 記述ルール (自然な日本語 / 番号付け禁止 / etc.)
```

## version

plugin 全体 (`.claude-plugin/plugin.json`) は 0.1.0 から start。各 skill は個別 semver:
- sadoku: 3.0.0 (レビュー咀嚼モード廃止で major)
- kouchiku: 2.0.0 (計画実行モード追加)
- tansaku: 2.0.0 (改名)
- shiken: 3.0.0 (改名 + 漢字ラベル変更)
- teishutsu: 0.1.0 (新規)
- wt: 0.1.0 (MVP)

## ライセンス / 出典

- License: MIT (`LICENSE` 参照)
- ベース: [tw93/Waza](https://github.com/tw93/Waza)
- 参考: [anthropic/superpowers](https://github.com/anthropic/superpowers)

## contributing

issues / PRs を歓迎します。新しい skill 追加よりも、既存 skill の磨き込みを優先する pack 哲学です。
