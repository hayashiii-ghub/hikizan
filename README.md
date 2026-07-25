# hikizan：AIエージェント開発のスキルパック

hikizanは、AIエージェントの開発作業を「調べる・決める・作る・見る・出す・伝える」の6方向から補助する、日本語の[Agent Skills](https://agentskills.io/)スキルパックです。

[v0.10.5からv0.11系までの変更を見る](https://hikizan-v011-shimon.haygsiiii.chatgpt.site)

6つのスキルは固定工程ではありません。ただし「PRまで」のように終点を指定すれば、必要に応じて設計、実装、レビュー、修正、提出をつなぎ、途中で形式的な承認待ちを挟まず最後まで進めます。停止するときは、意味のある次の進め方だけを推奨順に`A` / `B` / `C`で返します。

プラグイン版は、依頼に合うスキルを見つけるための短い起動規則も読み込みます。必要なら、強制プッシュ・破壊的操作・下書きでもレビュー担当付きでもないPR作成を止めるフックも追加できます。

## 導入方法を選ぶ

hikizanの導入方法は2つです。同じハーネスへ両方を入れないでください。

| 欲しいもの | 導入方法 | 向いているケース |
| --- | --- | --- |
| スキルだけ | Agent Skills | まず試したい、既存の操作を変えたくない |
| スキル + 起動規則 + 安全フック | 各ハーネスのプラグイン | スキルを確実に使い分け、危険な操作も機械的に止めたい |

<!-- hikizan:pack-only -->
配布と互換性確認はパック単位です。各スキルは独立して使え、固定順の引き継ぎを要求しません。

### エージェントに依頼する（推奨）

利用中のClaude Code、Codex、Cursor、OpenCodeなどで、エージェントに依頼するのが一番簡単です。

> hayashiii-ghub/hikizanのREADMEとマニフェストを確認し、現在のハーネスへ設定してください。最初にスキルだけにするか安全フックも付けるか確認し、既存設定と重複しない標準の方法を選んでください。変更内容を提示してから適用し、最後にスキルの検出を確認してください。

hikizan自体はインストーラーやハーネス別の設定状態を持ちません。利用中ハーネスのエージェントが既存設定を確認し、スキルだけか標準プラグインのどちらか一方を選びます。

### 手動で導入する

エージェントが設定を変更できない場合は、使うハーネスに対応する1つの方法だけを選びます。

スキルだけ：

```bash
npx skills add github:hayashiii-ghub/hikizan -g
```

Claude Codeプラグイン：

```text
/plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git
/plugin install hikizan@hikizan
```

Codexプラグイン：

```bash
codex plugin marketplace add hayashiii-ghub/hikizan
codex plugin add hikizan@hikizan
```

Cursorプラグインは、プラグイン画面からGitHubリポジトリ`hayashiii-ghub/hikizan`を追加します。

OpenCodeは、スキルパックを導入したうえで、リポジトリ内のローカルアダプターをプラグインディレクトリへリンクします。

```bash
git clone https://github.com/hayashiii-ghub/hikizan.git
cd hikizan
npx skills add github:hayashiii-ghub/hikizan -g
mkdir -p ~/.config/opencode/plugins
ln -s "$(pwd)/hooks/adapters/opencode/hikizan.ts" ~/.config/opencode/plugins/hikizan.ts
```

リンク先が既にある場合は置換せず、内容を確認してください。

導入後は新しい作業を開始し、旧版や別経路のスキルが重複していないことを確認してください。

### 対応範囲

| 実行環境 | 保証する範囲 | 検証方法 |
| --- | --- | --- |
| Claude Codeプラグイン | スキル + 起動規則 + 安全フック | 起動時の規則とClaude形式の3つの安全下限をCIで検査 |
| Codexプラグイン | スキル + 起動規則 + 安全フック | 起動時の規則とCodex形式の3つの安全下限をCIで検査 |
| Cursorプラグイン | スキル + 起動規則 + 安全フック | 常時適用する規則とCursor形式の3つの安全下限をCIで検査 |
| OpenCode + ローカルアダプター | スキル + 起動規則 + 安全フック | システム文脈の規則と`tool.execute.before`形式の3つの安全下限をCIで検査 |
| Agent Skills対応ハーネス | スキルのみ | 6スキルの`frontmatter`にある`name`と共通リスク契約をCIで検査 |

そのほかのAgent Skills対応ハーネスでは、ハーネス標準の検出機能でスキルだけを利用できます。CIが保証するのは配布物、配線、アダプターの入出力までです。

`tansaku`の広域探索と`sadoku`の専門レビューは、利用中ハーネスで標準サブエージェントが使える場合だけ委譲します。使えない場合は同じ範囲を親エージェントが確認します。

## 使い方

やりたいことをそのまま依頼します。スキルが起動すると、作業前に`🌲 sekkei（設計）：実装方針を比較します`のような1行が表示されます。

| スキル | 役割 |
| --- | --- |
| `tansaku`（探索） | 調査自体が成果物のとき、コードの全体像・影響範囲・用語を整理する |
| `sekkei`（設計） | 明示的な方針比較、`Kill` / `Keep`評価、実装計画を作る |
| `jikkou`（実行） | 通常実装、原因診断、リスクに合うテストとコミット境界を扱う |
| `sadoku`（査読） | コード・実行仕様Markdownを独立レビューし、簡略化の余地を見る |
| `teishutsu`（提出） | PR本文、通常プッシュ、PR提出を扱う |
| `houkoku`（文章・伝達） | README、技術文書、記事、推敲、Slack、報告、リリースノート、引き継ぎを扱う |

検証量は変更規模ではなくリスクで決めます。局所的な可逆変更は最寄りの検査、ロジックやAPIの変更は回帰検査、高リスクな変更は対象レビューと全体検証まで行います。

## 画面の検証

UI・スタイル・配置・操作の変更では、[Shimon](https://github.com/hayashiii-ghub/shimon)を標準の視覚検証ハーネスとして使います。

Shimon本体やプロジェクト固有の`shimon.config.mjs`はhikizanに同梱しません。UIを持つ対象プロジェクトが、ShimonとChromiumをプロジェクト内に導入します。

```bash
npm install --save-dev @hayashiii/shimon
npx playwright install chromium
```

設定済みのプロジェクトでだけShimonを実行します。エージェントは今回必要なケースを`.shimon/task.mjs`へ書き、自動検査と全スクリーンショットを確認します。未導入・未設定の場合は自動インストールや別ツールへの切替をせず、視覚未確認として報告します。

## 安全フック

フックは実装方法を決めたり、コミットを禁止したりしません。入力から判定できる危険なシェル操作だけに介入します。

| 対象 | 止める条件 | 動作 |
| --- | --- | --- |
| プッシュ | 保護対象ブランチへの強制相当プッシュ、リモートより遅れたプッシュ | 拒否 |
| 破壊的なシェル操作 | `rm -rf`、`git reset --hard`など | Claude Code / Cursorは確認、Codex / OpenCodeは拒否 |
| PR作成 | `gh pr create`に`--draft`も`--reviewer`もない | 拒否 |

詳しい条件と限界は[hooks/conditions.md](hooks/conditions.md)を参照してください。フックは事故を減らす補助的な安全策であり、完全なセキュリティ境界ではありません。

## 起動の目安

<!-- hikizan:triggers:start -->
<!-- scripts/gen-trigger-docs.shがskills/*/SKILL.mdの`frontmatter`から生成。手動編集しない -->

| スキル | 起動トリガー |
|---|---|
| `tansaku` | 探索, 全体像把握, 影響範囲調査, 用語整理。調査自体が成果の場合に使い、設計・実装に必要な局所確認だけでは起動しない |
| `sekkei` | 設計判断, 方針決め, design decision, kill or keep, 計画立案 |
| `jikkou` | 計画実行, 実装, エラー診断, root cause, バグ修正 |
| `sadoku` | PR確認, レビュー, code review, プロジェクトレビュー, コード整理, simplify |
| `teishutsu` | PR提出, PR出す, PR ready, PR文書いて, PR description, submission, PR open |
| `houkoku` | 文章を書いて, 執筆, 推敲, リライト, READMEを書いて, 技術文書を書いて, 記事を書いて, 何をした, 結果を教えて, 完了報告, Slack共有, リリースノート, handoff |

発動条件の正本は各`SKILL.md`の`frontmatter`にある`description`です。
<!-- hikizan:triggers:end -->

## 開発

開発時の入口は[AGENTS.md](AGENTS.md)です。提出前の検証は次の1コマンドで実行します。

```bash
bash scripts/check-all.sh
```

バージョンの正本は`plugin.src.json`です。3つのプラグインマニフェストは`bash scripts/gen-manifests.sh`で生成します。
共通の起動規則は各`SKILL.md`の`when_to_use`から`bash scripts/gen-routing.sh`で生成します。

## ライセンス

[MIT License](LICENSE) — Copyright (c) 2026 hayashiii-ghub
