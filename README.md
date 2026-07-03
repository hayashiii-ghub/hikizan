# hikizan

hikizan は Claude Code plugin / Agent Skills 対応の skill pack。動詞単位で分割した主要 skill と、認知負荷を抑える運用方針を提供する。

設計の出発点は「AI agent が長く自走しすぎても、逐一確認を挟まれすぎても作業のテンポが落ちる」という不満。hikizan はその塩梅を **3 つの部品** で取る:

- **レール (skills)**：弱いモデル基準で書いた番号付き手順と穴埋めテンプレ。タスクの回し方が強くないモデルでも、上から実行すれば形になる。
- **opt-out (standard tier)**：hooks=floors のある環境では、SessionStart に「手順は守らなくてよい。ただし出口は固定」という前文を注入する。賢いモデルに余計な手順を課さず、成果物の形だけ揃える。
- **floors (hooks)**：push / PR / 破壊的操作を決定論的に止める下限。tier に関わらず効く。

**出口契約**: どのモデル・どの進め方でも、PR は `teishutsu` の 6 セクション (過程の trace を残す Workflow 節を含む) に収束させる。任せても流れを後から把握できる、が設計目標。

- repo: [https://github.com/hayashiii-ghub/hikizan](https://github.com/hayashiii-ghub/hikizan)
- license: MIT
- agent 向け作業ガイド: [AGENTS.md](AGENTS.md)

## core skill

| skill | 漢字 | 動詞 | 担当 |
| --- | --- | --- | --- |
| `tansaku` | 探索 | 探す | code map / impact scope / terminology scan |
| `sadoku` | 査読 | 見る | code review / simplify findings |
| `sekkei` | 設計 | 考える・決める | 設計判断 / 評価 / 計画立案 |
| `jikkou` | 実行 | 作る・直す | 計画実行 / root cause diagnosis / TDD 実装 |
| `teishutsu` | 提出 | 出す | PR 本文ドラフト / PR 提出フロー (remote / submodule / parent / cwd-aware gh) |
| `kaku` | 書く | 書く・直す | 日本語文章の執筆 / 推敲 (規範は `docs/writing-style.md`) |

各 SKILL.md は「共通ルール block + モード表 (複数モードの skill のみ) + 番号付き手順 + やってはいけないこと + 穴埋め報告」に絞り、手順詳細は `references/` に置く。`sekkei` が設計・計画を controller として保持し、承認後の実行と原因診断は `jikkou`、TDD は `jikkou` の TDD 実装モード、レビューは `sadoku`、提出は `teishutsu`、探索は `tansaku`、文章は `kaku` に渡す。

ユーティリティ skill `init` (`/hikizan:init`) は規約を project の CLAUDE.md に手動で書き込みたい時だけ使う (model 自動起動は無効)。

## install

対応ハーネスは Claude Code / Codex / Cursor の 3 つ。**1 つのハーネスには 1 つのチャネルだけ**で入れる。skill を 2 経路で入れると二重定義になり、古い側に誤 route する (実際に過去発生した障害)。

| ハーネス | 入るもの | 方法 |
| --- | --- | --- |
| Claude Code | skills + floors + 前文 | `/plugin` 2 コマンド (下記) |
| Codex | skills + floors + 前文 | `codex plugin` 2 コマンド (下記) |
| Cursor | skills + subagents + floors + 前文 rule | Plugins 画面で GitHub repo を追加 (下記) |
| その他の harness | skills のみ (tier は `guided` 既定) | `npx skills add` (下記) |

### Claude Code

```bash
# Claude Code セッション内で実行
/plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git
/plugin install hikizan@hikizan
```

skills + floors + 前文がまとめて入る。`.git` 付き HTTPS URL を明示すると SSH key 未設定環境でも clone できる。開発・検証時は `claude --plugin-dir ./hikizan` で直接読み込む。skill は namespace 規約で `/hikizan:tansaku` … `/hikizan:teishutsu` として呼ばれる。`npx skills add -a claude-code` は併用しない。

### Codex

```bash
codex plugin marketplace add hayashiii-ghub/hikizan
codex plugin install hikizan
```

skills + floors (force push deny / 破壊的操作 ask / 非 draft PR deny) + SessionStart 経由の前文がまとめて入り、`HIKIZAN_TIER=standard` を宣言できる。特定 version への固定は `--ref v0.7.1`。詳細と fallback (手動 hooks.json) は `codex/README.md`。`npx skills add -a codex` は併用しない。

### Cursor

Cursor の Plugins 画面で GitHub repo `hayashiii-ghub/hikizan` を plugin として追加する。manifest の floors (`beforeShellExecution` hook) + 前文 rule (`cursor/rules/hikizan.mdc`) に加えて `skills/` と `agents/` も auto-discover されるため、skills + subagents までまとめて入り、`HIKIZAN_TIER=standard` を宣言できる (実 Cursor で load と floors の発火を確認済み)。

追加時の commit に固定されるので、更新は Plugins 画面から行う。古い版が残ると旧 skill が routing を奪うため、更新後は重複 install が無いか確認する。詳細は `cursor/README.md`。`npx skills add -a cursor` は併用しない。

### その他の harness (skill pack)

hikizan は [Agent Skills 標準](https://agentskills.io) に沿った skill pack でもあり、対応 harness なら skills だけ入れられる (hooks は付かないため tier は `guided` 既定):

```bash
npx skills add github:hayashiii-ghub/hikizan -g   # universal (配置先 ~/.agents/skills/)
```

`-g` で global、省略時は project local。詳細は [vercel-labs/skills](https://github.com/vercel-labs/skills)。

### 更新 (skill pack 経路のみ)

更新は `npx skills update` で行う (skill pack のみ。hooks / floors は含まない)。skill の rename や削除を含む更新 (例: 0.5.9 の `kouchiku` → `sekkei` / `jikkou` 分割) では、旧 skill のコピーが配置先に残って routing を奪うことがある。更新後、下の[trigger 早見表](#trigger-早見表)に無い skill が配置先に残っていたら `npx skills remove <旧 skill 名>` で削除する。

## tier

tier は「環境構築時にどこまで仕組みを用意したか」を表す。skill 本文は両 tier 共通 (弱いモデル基準のレール) で、違いは opt-out 前文の有無だけ。

- **standard** (hooks=floors のある環境)：SessionStart hook (`session-context.sh`) が routing / ルールに加えて **opt-out 前文** (`templates/standard-preamble.md`：手順は自由、出口は固定) を注入する。Claude Code の `/plugin` は既定でこれ。host repo の CLAUDE.md は書き換えない。
- **guided** (floors 未導入の環境・タスクの回し方が強くないモデル)：skill の番号付き手順を上から実行する。`HIKIZAN_TIER` 環境変数で tier を上書きできる。
- ファイルとして規約を残したい場合のみ `/hikizan:init` で project の CLAUDE.md に追記する。

## hooks (Claude Code の floors)

`hooks/hooks.json` 経由で CC の tool 呼び出しを監視し、定義済み条件に該当する時だけ介入する。skill 本文は通常フローの手順、hook は skill を経由しない操作への補完検査。

| hook | event | 介入 |
| --- | --- | --- |
| `session-context` | SessionStart | routing / ルール / tier (+ standard なら opt-out 前文) を context に注入 (書き込みなし) |
| `pre-push` | PreToolUse `git push` | non-fast-forward / 保護 branch への force を `deny` |
| `pre-destructive` | PreToolUse `rm` / `git reset` / `clean` / `checkout` | 不可逆操作を `ask` (確認要求) |
| `pre-pr-create` | PreToolUse `gh pr create` | draft / reviewer 未指定を `deny` |

決定は公式の JSON `permissionDecision` 形式 (`deny` / `ask`)。発火条件マトリクスと既知の限界は `hooks/conditions.md` (SoT)。決定論ロジックは `hooks/tests/` で回帰検査する (`bash hooks/tests/run.sh`)。発火イベントは `~/.hikizan/metrics.jsonl` に記録 (`HIKIZAN_METRICS_DIR` で変更可)。

## trigger 早見表

<!-- hikizan:triggers:start -->
<!-- generated by scripts/gen-trigger-docs.sh from skills/*/SKILL.md frontmatter — do not edit by hand -->

| skill | 起動トリガー |
|---|---|
| `tansaku` | 探索, 全体像把握, 影響範囲調査, 用語整理 |
| `sadoku` | PR確認, レビュー, code review, プロジェクトレビュー, コード整理, simplify |
| `sekkei` | 設計判断, 方針決め, design decision, kill or keep, 計画立案 |
| `jikkou` | 計画実行, 実装, エラー診断, root cause, バグ修正 |
| `teishutsu` | PR提出, PR出す, PR ready, PR文書いて, PR description, submission, PR open |
| `kaku` | 執筆, 推敲, リライト, 文章を書く |

各 skill の mode 別トリガーと遷移は `docs/workflow.md`、発動条件の正本は各 SKILL.md frontmatter `description`。
<!-- hikizan:triggers:end -->

## 外部 plugin 併用

hikizan は orchestration / LSP 本体を抱え込まない。必要なら公式 plugin を別途 install する。

- **Codex**: `/plugin install codex@openai-codex` (OpenAI 公式 [codex-plugin-cc](https://github.com/openai/codex-plugin-cc))。namespace で `/hikizan:*` と衝突しない。Codex 経由のコマンドも CC の Bash を通る限り同じ hook が効く。
- **LSP**: `/plugin install typescript-lsp@anthropic` 等。各 language server バイナリは別途要求 (`typescript-language-server` / `pyright` / `rust-analyzer`)。hikizan の skill は「シンボル系は LSP、テキスト系は grep、未設定なら grep fallback」で書かれており、未導入でも動作する (精度は落ちる)。

## quick start

1. Claude Code で install (上記)。別ハーネス含む全チャネルは [install](#install)。
2. `コードレビューして` → `/hikizan:sadoku` が通常レビューを実行。
3. 他の trigger は上の [trigger 早見表](#trigger-早見表) を参照。

継続実行 (`/goal` 相当) の運用例は `docs/workflow.md`。hikizan は loop engine ではなく loop 内の判断規約として使う。

## 設計原則

設計原則は `docs/principles.md` を参照 (レール・opt-out・floors / 弱いモデル基準で書く / 出口契約 / 環境変化評価 / Vertical TDD / 単一ソース 等)。

## ディレクトリ構成

```
hikizan/
├── README.md / AGENTS.md / LICENSE / .gitignore
├── .claude-plugin/        ← plugin.json / marketplace.json
├── agents/                ← first-class subagent 定義 (reviewer-security / -architecture)
├── cursor/                ← Cursor 用 floors adapter (before-shell.sh / hooks.json テンプレ)
├── hooks/
│   ├── hooks.json / conditions.md
│   ├── scripts/           ← session-context / pre-push / pre-destructive / pre-pr-create
│   │   └── lib/           ← push-parse / destructive / decision / decision-cursor / metrics
│   └── tests/             ← 自己完結 test runner (run.sh + test-*.sh)
├── scripts/               ← gen-trigger-docs.sh / check-consistency.sh
├── templates/             ← CLAUDE.md (routing/ルールの単一ソース、注入 & /hikizan:init が共用)
│                            standard-preamble.md (standard tier 専用の opt-out 前文)
│                            AGENTS.md (他 project へ配る AGENTS スケルトン)
├── skills/                ← SKILL.md (SoT) + references/
│   ├── tansaku / sadoku / sekkei / jikkou / teishutsu / kaku / init
└── docs/                  ← workflow.md / principles.md / writing-style.md / naming.md / doc-format.md / cursor-floors.md
```

## version

`.claude-plugin/plugin.json` に semver を明示する。公開時は変更内容に合わせて更新する。bump commit を main に merge したら、その commit に tag `v<version>` を打つ (CI の tag-version が plugin.json との一致を検査する)。

## ライセンス / acknowledgements

- License: MIT (`LICENSE`)
- Inspired by: [tw93/Waza](https://github.com/tw93/Waza) · [obra/superpowers](https://github.com/obra/superpowers) · [mattpocock/skills](https://github.com/mattpocock/skills)
