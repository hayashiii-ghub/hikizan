# hikizan

hikizan は Claude Code plugin / Agent Skills 対応の skill pack。動詞単位で分割した 4 つの主要 skill と、認知負荷を抑える運用方針を提供する。

設計の出発点は「AI agent が長く自走しすぎても、逐一確認を挟まれすぎても作業のテンポが落ちる」という不満。hikizan はその塩梅を、リスクに応じて振る舞いを切り替えることで取る — 低リスクで推測可能なことは自律で進め、計画の分岐点では確認を取り、不可逆・破壊的な操作では必ず止まる。固定の折衷点ではなく、場面ごとに自律と確認のバランスを変える設計。

4 skill (sadoku / kouchiku / shiken / teishutsu) は、設計・実装・レビュー・提出の各工程を担当する。

- repo: [https://github.com/hayashiii-ghub/hikizan](https://github.com/hayashiii-ghub/hikizan)
- license: MIT

## core 4 skill


| skill       | 漢字  | 動詞     | 担当                                                                       |
| ----------- | --- | ------ | ------------------------------------------------------------------------ |
| `sadoku`    | 査読  | 見る     | code review / simplify findings                                          |
| `kouchiku`  | 構築  | 考える・作る | 設計判断 / 評価 / 計画策定 / 計画実行 / root cause diagnosis                           |
| `shiken`    | 試験  | 試す     | TDD discipline / PRUNE                                                   |
| `teishutsu` | 提出  | 出す     | PR 本文ドラフト / PR 提出フロー (remote / submodule / parent commit / cwd-aware gh) |


各 skill は動詞単位で責務を分ける。`kouchiku` は controller として設計、計画実行、原因調査を扱う。TDD discipline は `shiken`、レビューは `sadoku`、PR 本文ドラフト / PR 提出プロセスは `teishutsu` に handoff block で渡す。

TDD 必要層では、`kouchiku` が実装を vertical behavior slice に分解し、`shiken` が 1 slice ごとに RED → GREEN → PRUNE を実行する。test level / coverage gap / PRUNE witness は `shiken` の return log に残す。

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


| ツール                          | path                                                           |
| ---------------------------- | -------------------------------------------------------------- |
| Cursor                       | `~/.cursor/skills/` (global) または `./.cursor/skills/` (project) |
| Claude Code                  | `~/.claude/skills/` (global) または `./.claude/skills/` (project) |
| Cline / OpenCode 等 universal | `~/.agents/skills/` または `./.agents/skills/`                    |


## hooks

hikizan は `hooks/hooks.json` 経由で CC の Bash ツール呼び出しを監視し、定義済みの条件に該当するときだけ介入します。skill 本文は通常フローの手順を示し、hook は skill を経由しない操作に対する補完的な検査を担当します。

4 つの hook を定義しています: `SessionStart` で `templates/CLAUDE.md` の内容を重複なく追加、`git push` / `gh pr create` の介入条件チェック、`git commit` 後の submodule pointer 整合性 warning。**発火条件マトリクスは `hooks/conditions.md` を参照** (SoT)。

発火イベントは `~/.hikizan/metrics.jsonl` に 1 行 1 JSON で記録されます (環境変数 `HIKIZAN_METRICS_DIR` で書き込み先変更可)。

## 外部 plugin 併用

hikizan は orchestration 本体を抱え込まない設計。Codex 連携と LSP は公式 plugin を別途 install します。

### Codex

特定タスクだけ Codex に委譲したい場合は、OpenAI 公式の [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) を hikizan と並行で install します。

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


| LSP plugin          | 言語                      | バイナリ install                                                                   |
| ------------------- | ----------------------- | ------------------------------------------------------------------------------ |
| `typescript-lsp`    | TypeScript / JavaScript | `npm install -g typescript-language-server typescript`                         |
| `pyright-lsp`       | Python                  | `pip install pyright` (または `npm install -g pyright`)                           |
| `rust-analyzer-lsp` | Rust                    | [rust-analyzer 公式手順](https://rust-analyzer.github.io/manual.html#installation) |


hikizan の skill は **「シンボル系は LSP、テキスト系は grep、LSP 未設定なら grep にフォールバック」** の規約で書かれているため、LSP plugin を入れていない環境でも grep ベースで動作します (精度は落ちる)。

## quick start

install 後に skill 起動を確認する手順。

1. Claude Code セッションで install:
  ```
   /plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git
   /plugin install hikizan@hikizan
  ```
   別ハーネス (Cursor / Codex) は [install (skill pack)](#install-skill-pack) 参照。
2. 入力例:
  ```
   コードレビューして
  ```
   → `/hikizan:sadoku` が起動して review を実行する。
3. 他の trigger は下の [trigger 早見表](#trigger-早見表) を参照。

## trigger 早見表

install 後、各 skill は以下の入力で起動する。

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

1. **skill 構成**: 1 skill に複数 mode / references は分離 / 決定論的な処理は scripts に置く
2. **Controller Owns Information**: 情報取得だけが目的の subagent はデフォルトで使わない
3. **inline 既定、subagent は明示 gate**: subagent を使うのは (a) 重い情報取得 / (b) specialist review / (c) 機械的な fan-out の 3 つに限る
4. **起動と文脈の明示**: announce-at-start / worktree の Step 0 検出 / Hard Rules 冒頭の 1 文ガード
5. **日本語圏への最適化**: skill 名は短い英語、本文は日本語、固有名詞 (TDD, mock, RED/GREEN/REFACTOR/PRUNE 等) は英語のまま残す
6. **評価は「環境変化」で見る**: 完了記録のうち機械的に検証できる項目は command の出力をそのまま引用し、自己申告は不可とする
7. **文章の可読性**: 4 つのチェック (結論を先に出す / 1 段落 1 主張 / 読み手の語彙 / 儀礼的表現を削る)
8. **認知負荷の削減**: 選択肢の提示 + 推奨度 N/10 + 1 行根拠 / 構造変更は図・線形手順は箇条書き / 読み手の負荷を優先する。PR 粒度・テスト最小化と同様に、全 skill に適用する
9. **Vertical TDD**: `kouchiku` は次に閉じる 1 つの observable behavior を slice として切り、`shiken` はその slice の output が壊れた時に落ちる test だけを残す
10. **工数は token 規模で考える**: 重さは「人間の作業時間」ではなく token 消費 / context 占有 / API コストで捉える。行数・ファイル数はその proxy。実行者は AI agent であることを前提とする
11. **ファクトチェック**: 知識カットオフより後の事実や不確実な情報は、検索・fetch・一次ソースで裏取りしてから断定する

## ディレクトリ構成

```
hikizan/
├── README.md                    ← 利用者向けの入口 (GitHub で最初に表示)
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

## ライセンス / acknowledgements

- License: MIT (`LICENSE` 参照)
- Inspired by / references:
  - [tw93/Waza](https://github.com/tw93/Waza)
  - [obra/superpowers](https://github.com/obra/superpowers)

