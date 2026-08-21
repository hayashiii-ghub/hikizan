# hikizan：AIエージェント開発のスキルパック

hikizanは、AIエージェントの開発作業を「調べる・決める・作る・見る・出す・伝える」の6方向から補助する、日本語の[Agent Skills](https://agentskills.io/)スキルパックです。ルートの`plugin.json`は[Agent Plugins](https://agent-plugins.org/) v1に準拠しています。

6つのスキルは固定工程ではありません。ただし「PRまで」のように終点を指定すれば、必要に応じて設計、実装、レビュー、修正、提出をつなぎ、途中で形式的な承認待ちを挟まず最後まで進めます。停止するときは、意味のある次の進め方だけを推奨順に`A（あ）` / `I（い）` / `U（う）`で返し、英字とひらがなのどちらでも選べます。

プラグイン版は、依頼に合うスキルを見つける短い規則と、作業開始時のリポジトリ状態を読み込みます。

## v1で守ること

v1では、次の振る舞いを互換性の基準とします。

- 6つのスキルIDと、それぞれを独立した観点として扱う構成
- 調査、相談、設計、レビューだけの依頼では対象を変更しない境界
- 修正、追加、削除、実行が明示された場合だけ実装を始める境界
- PRマージと既定ブランチへの直接のpushは、依頼の終点として明示された場合だけ行う境界
- ハーネスに依存しない`skills/`と、任意で追加できるHookの分離

## 導入方法を選ぶ

hikizanの配布形式は、共通のAgent Plugins、Claude Codeプラグイン、piパッケージです。通常は使用中のハーネスに合う形式を選ぶだけで、Skillsと利用可能な起動情報がまとめて設定されます。

| 実行環境 | 推奨する導入方法 |
| --- | --- |
| Claude Code | Claude Codeプラグイン |
| Codex | Agent Plugins + Codex Hookアダプター |
| Cursor | Agent Plugins + Cursor Hookアダプター |
| pi | piパッケージ |
| その他 | Agent Plugins。未対応ならAgent Skills |

<!-- hikizan:pack-only -->
配布と互換性確認はパック単位です。各スキルは独立して使え、固定順の引き継ぎを要求しません。

### エージェントに依頼する（推奨）

利用中のClaude Code、Codex、Cursorなどで、エージェントに依頼するのが一番簡単です。

> hayashiii-ghub/hikizanのREADMEとマニフェストを確認し、現在のハーネスに推奨される方法で設定してください。既存設定と重複しないことを確認し、変更内容を提示してから適用してください。最後にスキルの検出と、対応している場合は起動情報を確認してください。

hikizan自体はインストーラーやハーネス別の設定状態を持ちません。利用中ハーネスのエージェントが既存設定を確認し、その環境の標準的な方法を選びます。

### 手動で導入する

エージェントが設定を変更できない場合は、使うハーネスに対応する1つの方法だけを選びます。

Claude Codeプラグイン：

```text
/plugin marketplace add https://github.com/hayashiii-ghub/hikizan.git
/plugin install hikizan@hikizan
```

CodexのHookアダプター：

```bash
codex plugin marketplace add hayashiii-ghub/hikizan
codex plugin add hikizan@hikizan
```

piパッケージ：

```bash
pi install git:github.com/hayashiii-ghub/hikizan
```

piでは6スキル、起動時のリポジトリ状態、文字ベースのヘッダー、[shimon](https://github.com/hayashiii-ghub/shimon)の`shimon_verify`がまとめて読み込まれます。`/hikizan`でヘッダーの表示を切り替えられます。

`shimon_verify`は設定ファイルなしで使えます。Chromiumをまだ導入していない環境だけ、初回に次を実行してください。ブラウザー本体はhikizanのインストール時に自動ダウンロードしません。

```bash
npx playwright install chromium
```

以前にshimonを単体のpiパッケージとして導入している場合は、`pi list`でshimonのsourceを確認し、`pi remove <source>`で外してからhikizanを更新してください。同じ`shimon_verify`を2つのパッケージから登録するとpiが起動を拒否します。

ExaのAPIキーを設定してpiを起動すると、追加設定なしで任意の`web_search`も使えます。キーがなければ検索ツール自体を登録せず、従来のhikizanとして動作します。

```bash
read -s EXA_API_KEY
export EXA_API_KEY
pi
```

APIキーの入力内容は画面へ表示されません。macOSでは、キーをコピーして`EXA_API_KEY="$(pbpaste)" pi`でも起動できます。

検索語はExaへ送信されますが、APIキー、検索語、結果、利用状況をhikizan側で保存しません。検索は`fast`、既定5件、最大10件、10秒のタイムアウトに固定しています。HTTP 402では再試行や有料サービスへの切り替えをせず停止します。従量課金の上限は、Exa側でAPIキーごとの予算も設定してください。

CursorのHookアダプターは、プラグイン画面からGitHubリポジトリ`hayashiii-ghub/hikizan`を追加します。

そのほかのAgent Plugins対応クライアントでは、このGitHubリポジトリをクライアント標準の方法で追加します。ルートの`plugin.json`と`skills/`が読み込まれます。

Skillsだけを軽量に試す場合：

```bash
npx skills add github:hayashiii-ghub/hikizan -g
```

導入後は新しい作業を開始し、旧版や別経路のスキルが重複していないことを確認してください。

### 対応範囲

| 実行環境 | 提供する範囲 | リポジトリ内の確認 |
| --- | --- | --- |
| Claude Codeプラグイン | スキル + 起動情報 | マニフェスト、配線、Hook出力をCIで検査 |
| Codex + Hookアダプター | Agent Pluginsのスキル + 起動情報 | マニフェスト、配線、Hook出力をCIで検査 |
| Cursor + Hookアダプター | Agent Pluginsのスキル + 起動情報 | マニフェスト、配線、Hook出力をCIで検査 |
| piパッケージ | スキル + 起動情報 + TUI + 画面検証 + 任意Web検索 | マニフェストと配線をCIで検査。piがある環境では起動も確認 |
| Agent Plugins対応クライアント | スキル | ルート`plugin.json`と6スキルの構成をCIで検査 |
| Agent Skills対応ハーネス | スキルのみ | 6スキルの`frontmatter`にある`name`、`description`、共通契約をCIで検査 |

そのほかのAgent Skills対応ハーネスでは、ハーネス標準の検出機能でスキルだけを利用できます。CIが確認するのは配布物、配線、アダプターの入出力までで、各ハーネス本体を起動するE2E検証は含みません。

`tansaku`の広域探索と`sadoku`の専門レビューは、利用中ハーネスで標準サブエージェントが使える場合だけ委譲します。使えない場合は同じ範囲を親エージェントが確認します。

## 使い方

やりたいことをそのまま依頼します。スキルが起動すると、作業前に`🌲 sekkei（設計）：実装方針を比較します`のような1行が表示されます。

| スキル | 役割 |
| --- | --- |
| `tansaku`（探索） | 調査自体が成果物のとき、コードの全体像・影響範囲・用語を整理する |
| `sekkei`（設計） | 明示的な方針比較、`Kill` / `Keep`評価、実装計画を作る |
| `jikkou`（実行） | 明示された実装、障害修正、リスクに合うテストとコミット境界を扱う |
| `sadoku`（査読） | コード・実行仕様Markdownを独立レビューし、簡略化の余地を見る |
| `teishutsu`（提出） | PR本文、通常プッシュ、PR提出を扱う |
| `houkoku`（文章・伝達） | README、技術文書、記事、推敲、Slack、報告、リリースノート、引き継ぎ、静的HTMLを扱う |

検証量は変更規模ではなくリスクで決めます。局所的な可逆変更は最寄りの検査、ロジックやAPIの変更は回帰検査、高リスクな変更は対象レビューと全体検証まで行います。

## 画面の検証

UI・スタイル・配置・操作を変更したら、対象プロジェクトまたは現在のハーネスで利用できる視覚検証方法を使います。検査結果だけでなく、生成された画像や実際の表示も確認します。

[shimon](https://github.com/hayashiii-ghub/shimon)の`shimon_verify`が利用可能なら、起動済みの画面URLと今回必要なケースを渡して使います。通常はプロジェクト側の設定ファイルを必要としません。piパッケージにはshimonを含み、そのほかのハーネスでは既に利用できる視覚検証方法を使います。利用できる方法がなければ、視覚未確認であることを伝えます。

## フック

フックは次の2つだけを扱います。

- 依頼に合うスキルを見つける短い規則を渡す
- 現在のリポジトリ、ブランチ、作業ツリー、upstreamとの差分を知らせる

piでは同じ起動情報に加え、hikizanのAA、6スキル、実行状態を示す短いステータスと`shimon_verify`を提供します。狭いターミナルでは短い文字表示へ縮退します。`EXA_API_KEY`がある場合だけ、低遅延の`web_search`も登録します。

リモート確認に失敗しても作業は止めず、`未確認`と表示します。PRマージと既定ブランチへの直接のpushはHookで解析せず、明示された依頼に基づいて判断します。詳しい責務は[hooks/conditions.md](hooks/conditions.md)を参照してください。

## 起動の目安

<!-- hikizan:triggers:start -->
<!-- scripts/gen-trigger-docs.shがskills/*/SKILL.mdの`frontmatter`から生成。手動編集しない -->

| スキル | 起動トリガー |
|---|---|
| `tansaku` | コードベースの全体像、影響範囲、原因、固有用語など、調査結果そのものを求める依頼に使う。対象は変更せず、設計や実装に必要な局所確認だけでは使わない。 |
| `sekkei` | 方針比較、設計判断、ゼロベース評価、実装計画を求める依頼に使う。実装が依頼に含まれていなければ対象を変更せず、設計結果を返して止まる。 |
| `jikkou` | コード、設定、文書の修正・追加・削除、または決定済み計画の実行を明示した依頼に使う。調査、相談、設計、レビューだけの依頼では使わない。 |
| `sadoku` | コード、差分、PR、実行可能なプロジェクト指示のレビューや簡略化案を求める依頼に使う。正しさ、既存コードとの整合、セキュリティ、より単純な表現を確認し、レビュー中は対象を変更しない。 |
| `teishutsu` | PR本文の作成、または完成した変更の通常プッシュとPR作成を明示した依頼に使う。実装とPRマージは扱わない。 |
| `houkoku` | README、技術文書、記事、Slack、報告、リリースノート、HTMLでまとめるなど、人へ渡す日本語文章の作成や推敲そのものを求める依頼に使う。文章の表現や構成が主目的でない局所修正では使わない。 |

発動条件の正本は各`SKILL.md`の`frontmatter`にある`description`です。
<!-- hikizan:triggers:end -->

## 開発

開発時の入口は[AGENTS.md](AGENTS.md)です。提出前の検証は次の1コマンドで実行します。

```bash
bash scripts/check-all.sh
```

バージョンの正本は`plugin.src.json`です。Agent Plugins、Claude Code、Codex・CursorのHookアダプター用マニフェストとpi用`package.json`は`bash scripts/gen-manifests.sh`で生成します。
共通の起動規則は各`SKILL.md`の`description`から`bash scripts/gen-routing.sh`で生成します。

## ライセンス

[MIT License](LICENSE) — Copyright (c) 2026 hayashiii-ghub
