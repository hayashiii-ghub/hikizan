# hikizan

日本語圏チーム開発向けの Claude Code plugin / Agent Skills 対応 skill pack + git worktree CLI。tw93/Waza を起点に、SP (anthropic/superpowers) から選択的に取り込み、日本語圏 team-dev に最適化した **core 4 skill** と、並列開発を支える **`wt`** (worktree manager) を含む。

動詞単位で責務を分けた 4 skill (sadoku / kouchiku / shiken / teishutsu) と **引き算の哲学**を中核に据える。

- repo: <https://github.com/hayashiii-ghub/hikizan>
- license: MIT

## core 4 skill

| skill | 漢字 | 動詞 | 担当 |
|---|---|---|---|
| `sadoku` | 査読 | 見る | code review / simplify findings |
| `kouchiku` | 構築 | 考える・作る | 設計判断 / 評価 / 計画策定 / 計画実行 / root cause diagnosis |
| `shiken` | 試験 | 試す | TDD discipline / PRUNE |
| `teishutsu` | 提出 | 出す | PR 本文ドラフト / PR 提出フロー (remote / submodule / parent commit / cwd-aware gh) |

動詞で 4 分割した役割境界が原則。`kouchiku` は controller として設計から計画実行、原因調査までを持ち、TDD discipline は `shiken`、レビューは `sadoku`、PR 本文ドラフト / PR 提出プロセスは `teishutsu` に handoff block で渡す。

## install (Claude Code plugin)

Claude Code 利用者は `/plugin` 経由が推奨経路。

```bash
# Claude Code セッション内で実行
/plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git
/plugin install hikizan@hikizan
```

`.git` 付き HTTPS URL を明示すると、GitHub SSH key 未設定の環境でも git repository として clone できます。

開発・検証時は `--plugin-dir` で直接読み込み:

```bash
git clone https://github.com/hayashiii-ghub/hikizan
claude --plugin-dir ./hikizan
```

skill 名は namespace 規約により `/hikizan:sadoku` / `/hikizan:kouchiku` / `/hikizan:shiken` / `/hikizan:teishutsu` で呼ばれる。

## install (skill pack)

hikizan は [Agent Skills 標準](https://agentskills.io) にも沿った **skill pack** です。skills-compatible agent (Cursor / Codex / Claude Code) へ `skills` CLI で配置できます。

> Codex を Claude Code 経由で呼びたい場合は下の [外部 plugin 併用](#外部-plugin-併用) 節を参照してください。skill pack 単独で Codex を直接動かしたい場合のみ、本節の手順 (`npx skills add -a codex`) を使います。

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

### 配置先

`npx skills add` は各 skill を対象ツールの skills ディレクトリに配置する。Claude Code は `~/.claude/skills/<skill>/`、Cursor は `~/.cursor/skills/<skill>/`。各ツールはそのディレクトリを auto-discovery する。

### 手動配置 (npx を使わない場合)

`skills/<name>/` を各ツールの skills dir にコピー or symlink:

| ツール | path |
|---|---|
| Cursor | `~/.cursor/skills/` (global) または `./.cursor/skills/` (project) |
| Claude Code | `~/.claude/skills/` (global) または `./.claude/skills/` (project) |
| Cline / OpenCode 等 universal | `~/.agents/skills/` または `./.agents/skills/` |

waza の `kakunin` / `kentou` / `tsuiseki` 等とは skill 名が違うので衝突せず共存可能。

## hooks による安全網

hikizan は `hooks/hooks.json` 経由で CC の Bash ツール呼び出しを監視し、定義済みの条件に該当するときだけ介入します。skill 本文は正常経路で漏れを防ぎ、hook は「skill を経由しない経路でも止める最後の砦」を担当します。

4 つの hook が動きます: `SessionStart` で `templates/CLAUDE.md` の内容を重複なく追加、`git push` / `gh pr create` の介入条件チェック、`git commit` 後の submodule pointer 整合性 warning。**発火条件マトリクスは `hooks/conditions.md` を参照** (SoT)。

発火イベントは `~/.hikizan/metrics.jsonl` に 1 行 1 JSON で記録されます (環境変数 `HIKIZAN_METRICS_DIR` で書き込み先変更可)。

## 外部 plugin 併用

hikizan は orchestration 本体を抱え込まない設計。Codex 連携と LSP は公式 plugin を別途 install します。

### Codex

特定タスクだけ Codex に下請けさせたい場合は、OpenAI 公式の [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) を hikizan と並行で install します。

```bash
# Claude Code セッション内で実行
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/codex:setup
```

namespace 規約により `/hikizan:*` と `/codex:*` は衝突しません。要件は ChatGPT subscription または OpenAI API key と、ローカルの Codex CLI (`npm install -g @openai/codex`)。hikizan の hooks は CC 本体の Bash ツール呼び出しに発火するため、Codex 経由で実行されるコマンドが CC の Bash を通る限り同じ停止条件が効きます。

### LSP

シンボル探索 (関数 / クラス / 変数の定義 / 参照) に LSP の正確性が必要な場合は、CC 公式 marketplace から各言語の LSP plugin を install します。

```bash
# Claude Code セッション内で実行 ( /plugin Discover タブで "lsp" を検索しても同じ )
/plugin install typescript-lsp@anthropic
/plugin install pyright-lsp@anthropic
/plugin install rust-analyzer-lsp@anthropic
```

各 LSP plugin は **language server バイナリを別途要求**します:

| LSP plugin | 言語 | バイナリ install |
|---|---|---|
| `typescript-lsp` | TypeScript / JavaScript | `npm install -g typescript-language-server typescript` |
| `pyright-lsp` | Python | `pip install pyright` (または `npm install -g pyright`) |
| `rust-analyzer-lsp` | Rust | [rust-analyzer 公式手順](https://rust-analyzer.github.io/manual.html#installation) |

hikizan の skill は **「シンボル系は LSP、テキスト系は grep、LSP 未設定なら grep にフォールバック」** の規約で書かれているため、LSP plugin を入れていない環境でも grep ベースで動作します (精度は落ちる)。

## install (wt — git worktree CLI)

並列開発で worktree を扱うための CLI。skill とは独立、bash 単体。

### Claude Code plugin 経由 (推奨)

`/plugin install hikizan@hikizan` を実行している場合、`bin/wt` は CC plugin の `bin/` 機構によりセッション中の Bash ツールの `PATH` に自動追加されます。追加手順は不要、Claude Code 内で直接呼び出せます:

```bash
wt help
```

### skill pack 単独利用 / shell から直接使いたい場合

`npx skills add` 経由で skill だけ入れている、または CC 外の shell から `wt` を叩きたい場合は、手動で symlink:

```bash
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

1. Claude Code セッションで install:

   ```
   /plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git
   /plugin install hikizan@hikizan
   ```

   別ハーネス (Cursor / Codex) は [install (skill pack)](#install-skill-pack) 参照。

2. 発話してみる:

   ```
   コードレビューして
   ```

   → `/hikizan:sadoku` が起動して review が走る。

3. 他の trigger は下の [trigger 早見表](#trigger-早見表) を参照。

## trigger 早見表

install 後、各 skill は発話で起動する。

```
"設計どうする"           → kouchiku 通常検討
"計画実行" / "進めて"     → kouchiku 計画実行
"レビューして"           → sadoku 通常レビュー
"整理して" / "simplify"   → sadoku simplify findings
"コードレビュー"          → sadoku 通常レビュー + simplify (compound)
"PR文書いて"            → teishutsu PR 本文ドラフト
"エラー" / "動かない"     → kouchiku diagnosis
"TDDで" / "テストから書いて" → shiken
"PR出す" / "PR提出"     → teishutsu
```

詳しい trigger 一覧と mode 切替は `docs/workflow.md` (mermaid 図入り) を参照。

## 設計原則

1. **waza 哲学の継承**: 1 つの skill に複数 mode / references は分離 / 決定論的な処理は scripts に置く
2. **Controller Owns Information**: 情報取得だけが目的の subagent はデフォルトで使わない
3. **inline 既定、subagent は明示 gate**: subagent を使うのは (a) 重い情報取得 / (b) specialist review / (c) 機械的な fan-out の 3 つに限る
4. **SP からの選択的な取り込み**: announce-at-start / worktree の Step 0 検出 / Hard Rules 冒頭の 1 文ガード を採用。Iron Law / Red Flags / Rationalization 表は採用しない
5. **日本語圏への最適化**: skill 名は短い英語、本文は日本語、固有名詞 (TDD, mock, RED/GREEN/REFACTOR/PRUNE 等) は英語のまま残す
6. **評価は「環境変化」で見る**: 完了記録のうち機械的に検証できる項目は command の出力をそのまま引用し、自己申告は禁止する
7. **文章は「伝わりやすさ」だけで判断する**: 4 つのチェック (結論を先に出す / 1 段落 1 主張 / 読み手の語彙 / 儀礼的表現を削る)
8. **引き算 (認知負荷の削減)**: 選択肢の提示 + 推奨度 N/10 + 1 行根拠 / 構造変更は図・線形手順は箇条書き / 読み手の負荷を最優先する。hikizan の他の原則 (PR 粒度・テスト最小化) と同じ「引き算」の哲学を全 skill で貫く
9. **工数は token 規模で考える**: 重さは「人間の作業時間」ではなく token 消費 / context 占有 / API コストで捉える。行数・ファイル数はその proxy。実行者は AI agent であることを前提とする
10. **ファクトチェック**: 知識カットオフより後の事実や不確実な情報は、検索・fetch・一次ソースで裏取りしてから断定する

## ディレクトリ構成

```
hikizan/
├── README.md                    ← この入口 (人間中心、GitHub で最初に表示)
├── AGENTS.md                    ← AI agent 入口 + routing
├── LICENSE                      ← MIT
├── .gitignore
├── .claude-plugin/              ← Claude Code plugin manifest (CC 経由配布用)
│   ├── plugin.json              ← plugin 本体の manifest
│   └── marketplace.json         ← 単一 plugin の marketplace (source: "./")
├── hooks/                       ← CC plugin hooks (SessionStart / PreToolUse / PostToolUse)
│   ├── hooks.json
│   ├── conditions.md            ← 停止条件マトリクス
│   └── scripts/
│       ├── lib/metrics.sh       ← ~/.hikizan/metrics.jsonl writer (silent on failure)
│       ├── bootstrap-claude-md.sh
│       ├── pre-push.sh
│       ├── pre-pr-create.sh
│       └── post-commit.sh
├── templates/
│   └── CLAUDE.md                ← SessionStart hook が必要なセクションを重複なく追加する
├── bin/
│   └── wt                       ← git worktree CLI (bash)
├── skills/                      ← skill 本体 (SoT、CC plugin / npx skills add の両経路で読まれる)
│   ├── sadoku/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── project-context.md
│   │       ├── persona-catalog.md
│   │       ├── simplify-checklist.md
│   │       └── agents/
│   │           ├── reviewer-security.md
│   │           └── reviewer-architecture.md
│   ├── kouchiku/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── diagnosis-techniques.md
│   │       └── minimal-approach.md
│   ├── shiken/
│   │   ├── SKILL.md
│   │   └── references/testing-anti-patterns.md
│   └── teishutsu/
│       ├── SKILL.md
│       └── references/pr-template.md
└── docs/
    └── workflow.md              ← 使い方ガイド (利用者向け、mermaid 図入り)
```

## version

hikizan は `.claude-plugin/plugin.json` に semver を明示する。公開時は変更内容に合わせて `version` を更新する。

## ライセンス / 出典

- License: MIT (`LICENSE` 参照)
- ベース: [tw93/Waza](https://github.com/tw93/Waza)
- 参考: [anthropic/superpowers](https://github.com/anthropic/superpowers)
