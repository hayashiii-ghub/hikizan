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
| `shippitsu` | 執筆 | 書く・直す | 日本語文章の執筆 / 推敲 (規範は `skills/shippitsu/references/writing-style.md`) |

各 SKILL.md は「共通ルール block + モード表 (複数モードの skill のみ) + 番号付き手順 + やってはいけないこと + 穴埋め報告」に絞り、手順詳細は `references/` に置く。`sekkei` が設計・計画を controller として保持し、承認後の実行と原因診断は `jikkou`、TDD は `jikkou` の TDD 実装モード、レビューは `sadoku`、提出は `teishutsu`、探索は `tansaku`、文章は `shippitsu` に渡す。

ユーティリティ skill `init` (`/hikizan:init`) は、ユーザが指定した project instruction Markdown (`CLAUDE.md` / `AGENTS.md` など) に規約を書き込みたい時だけ使う (model 自動起動は無効)。利用先 repo と書き込み先を推測せず、明示確認してから変更する。

## install

対応ハーネスは Claude Code / Codex / Cursor / OpenCode の4つ。**1つのハーネスには1つのチャネルだけ**で入れる。skillを2経路で入れると二重定義になり、古い側に誤routeする (実際に過去発生した障害)。

<!-- hikizan:pack-only -->
hikizan の skill は相互に handoff と共通契約を参照するため pack 単位で導入し、個別 skill だけの部分 install はサポートしない。

| ハーネス | 入るもの | 方法 | 検証状態 |
| --- | --- | --- | --- |
| Claude Code | skills + floors + 前文 | `/plugin` 2 コマンド (下記) | 検証済み (開発時に常用) |
| Codex | skills + floors + 前文 | `codex plugin` 2 コマンド (下記) | install 検証済み / hooks 発火は未 live 検証 |
| Cursor | skills + subagents + floors + 前文 rule | Plugins 画面で GitHub repo を追加 (下記) | 検証済み (実機確認 2026-07-03) |
| OpenCode | skills + floors + 前文 | skill pack + local TypeScript plugin (下記) | 実験的 (OpenCode 1.18.0でplugin load確認 / tool発火は結合テスト) |
| その他の harness | skills のみ (tier は `guided` 既定) | `npx skills add` (下記) | best-effort (harness 依存) |

検証状態の 3 分類: **検証済み** = 実環境で plugin load と floors の発火を確認済み。**実験的** = adapter の一部を実環境で未確認 (未 load または実 tool call で未発火)。**best-effort** = skills の配置のみで floors が無い (対象 harness の挙動に依存する)。

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
codex plugin add hikizan@hikizan
```

skills + floors (force push deny / 破壊的操作 deny / 非 draft PR deny) + SessionStart 経由の前文がまとめて入り、`HIKIZAN_TIER=standard` を宣言できる。特定 version への固定は marketplace 追加時に `--ref vX.Y.Z` を付け、`X.Y.Z` を実在する release tag の version に置き換える。Codex CLI 0.144.2 の隔離した `CODEX_HOME` で marketplace 追加・plugin install・一覧表示までは確認済み。install 後は hooks の内容を確認して信頼し、新しい task を開始する。実 tool call での hooks 発火は未 live 検証なので、floors は完全な security boundary ではなく補助 guardrail として扱う。詳細と fallback (手動 hooks.json) は `codex/README.md`。`npx skills add -a codex` は併用しない。

### Cursor

Cursor の Plugins 画面で GitHub repo `hayashiii-ghub/hikizan` を plugin として追加する。manifest の floors (`beforeShellExecution` hook) + 前文 rule (`cursor/rules/hikizan.mdc`) に加えて `skills/` と `agents/` も auto-discover されるため、skills + subagents までまとめて入る (実 Cursor で load と floors の発火を確認済み)。standard tier の前文は rule として届くので、guided で使いたい場合は rule を project の rules から外す (`HIKIZAN_TIER` 環境変数は Cursor では効かない)。

追加時の commit に固定されるので、更新は Plugins 画面から行う。古い版が残ると旧 skill が routing を奪うため、更新後は重複 install が無いか確認する。詳細は `cursor/README.md`。`npx skills add -a cursor` は併用しない。

### OpenCode

OpenCodeは`~/.agents/skills/`のskill packをnativeの`skill` toolで読み、`.opencode/plugins/`または`~/.config/opencode/plugins/`のTypeScript pluginを起動する。現時点ではnpm packageを公開していないため、repoをcloneしたlocal adapter方式のみサポートする。

```bash
git clone https://github.com/hayashiii-ghub/hikizan.git
cd hikizan
npx skills add github:hayashiii-ghub/hikizan -g
mkdir -p ~/.config/opencode/plugins
ln -sfn "$(pwd)/opencode/hikizan.ts" ~/.config/opencode/plugins/hikizan.ts
HIKIZAN_ROOT="$(pwd)" opencode
```

floors (force push deny / 破壊的操作deny / 非draft PR deny)、実行後metrics、system transform経由の前文が入る。`experimental.chat.system.transform`をSessionStart相当として使うため、OpenCodeのAPI変更時は追従が必要。詳細は`opencode/README.md`。skill packを別経路でも入れない。

### その他の harness (skill pack)

hikizan は [Agent Skills 標準](https://agentskills.io) に沿った skill pack でもあり、対応 harness なら skills だけ入れられる (hooks は付かないため tier は `guided` 既定):

```bash
npx skills add github:hayashiii-ghub/hikizan -g   # universal (配置先 ~/.agents/skills/)
```

選択画面が出る場合は hikizan の全 skill を選ぶ。`-g` で global、省略時は project local。詳細は [vercel-labs/skills](https://github.com/vercel-labs/skills)。

### 更新 (skill pack 経路のみ)

更新は `npx skills update` で行う (skill pack のみ。hooks / floors は含まない)。skill の rename や削除を含む更新 (例: 0.5.9 の `kouchiku` → `sekkei` / `jikkou` 分割) では、旧 skill のコピーが配置先に残って routing を奪うことがある。更新後、下の[trigger 早見表](#trigger-早見表)に無い skill が配置先に残っていたら `npx skills remove <旧 skill 名>` で削除する。

## tier

tier は「環境構築時にどこまで仕組みを用意したか」を表す。skill 本文は両 tier 共通 (弱いモデル基準のレール) で、違いは opt-out 前文の有無だけ。

- **standard** (hooks=floors のある環境)：SessionStart hook (`session-context.sh`) が routing / ルールに加えて **opt-out 前文** (`context/standard-preamble.md`：手順は自由、出口は固定) を注入する。Claude Code の `/plugin` は既定でこれ。host repo の CLAUDE.md は書き換えない。
- **guided** (floors 未導入の環境・タスクの回し方が強くないモデル)：skill の番号付き手順を上から実行する。
- **切替手段はハーネスで異なる**: Claude Code / Codex は `HIKIZAN_TIER` 環境変数で上書きする。Cursor は前文 rule (`cursor/rules/hikizan.mdc`) を project の rules に置くか外すかで切り替える (環境変数は効かない。詳細は `cursor/README.md`)。
- ファイルとして規約を残したい場合のみ `/hikizan:init` で、ユーザ指定の project instruction Markdown に追記する。

## hooks (Claude Code の floors)

`hooks/hooks.json` 経由で CC の tool 呼び出しを監視し、定義済み条件に該当する時だけ介入する。skill 本文は通常フローの手順、hook は skill を経由しない操作への補完検査。

| hook | event | 介入 |
| --- | --- | --- |
| `session-context` | SessionStart | routing / ルール / tier (+ standard なら opt-out 前文) を context に注入 (書き込みなし) |
| `pre-push` | PreToolUse `git push` | non-fast-forward / 保護 branch への force を `deny` |
| `pre-destructive` | PreToolUse `rm` / `git reset` / `clean` / `checkout` | 不可逆操作を `ask` (確認要求) |
| `pre-pr-create` | PreToolUse `gh pr create` | draft / reviewer 未指定を `deny` |
| `post-command` | PostToolUse `git push` / `gh pr create` ほか `rm` | floor 対象クラスのコマンド実行を記録 (介入なし。ask 承認率と bypass 検出の材料) |

この表は Claude Code 用。Cursorも破壊的操作を`ask`にするが、Codex / OpenCodeはhookから対話的な`ask`を返せないため同じ分類結果を`deny`にする。決定は各harnessの公式形式で返す。発火条件マトリクスと既知の限界は`hooks/conditions.md` (SoT)。決定論ロジックは`hooks/tests/`で回帰検査する (`bash hooks/tests/run.sh`)。発火イベントは`~/.hikizan/metrics.jsonl`に記録 (`HIKIZAN_METRICS_DIR`で変更可)。

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
| `shippitsu` | 執筆, 推敲, リライト, 文章を書く, 平坦な文章, 緩急, 読ませる文章 |

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
├── README.md / AGENTS.md / LICENSE / .gitignore / plugin.src.json (version 等の正本)
├── .claude-plugin/        ← plugin.json (生成物) / marketplace.json
├── agents/                ← first-class subagent 定義 (生成物、正本は skills/sadoku/references/agents/)
├── cursor/                ← Cursor 用 floors adapter (before-shell.sh / hooks.json テンプレ)
├── opencode/              ← OpenCode 用TypeScript adapter / local install手順
├── hooks/
│   ├── hooks.json / conditions.md
│   ├── scripts/           ← session-context / pre-push / pre-destructive / pre-pr-create
│   │   └── lib/           ← push-parse / destructive / decision / decision-cursor / metrics
│   └── tests/             ← 自己完結 test runner (run.sh + test-*.sh)
├── scripts/               ← gen-*.sh / check-*.sh / skills.json (core skill 集合の正本)
├── context/               ← 常駐 context の正本 (routing.md + standard-preamble.md、注入 & rule & init reference の生成元)
├── skills/                ← SKILL.md (SoT) + references/
│   ├── tansaku / sadoku / sekkei / jikkou / teishutsu / shippitsu / init
│   │                        (命名規範は teishutsu/references/naming.md、文章規範は shippitsu/references/writing-style.md)
└── docs/                  ← workflow.md / principles.md / doc-format.md
```

## version

version の正本は repo 直下の `plugin.src.json` (3 つの plugin manifest は `scripts/gen-manifests.sh` の生成物)。公開時は変更内容に合わせて更新する。bump commit を main に merge したら、その commit に tag `v<version>` を打つ (CI の tag-version が plugin.json との一致を検査する)。

## ライセンス / acknowledgements

- License: MIT (`LICENSE`)
- Inspired by: [tw93/Waza](https://github.com/tw93/Waza) · [obra/superpowers](https://github.com/obra/superpowers) · [mattpocock/skills](https://github.com/mattpocock/skills)
