# piで使う

[導入方法はREADME](../../../README.md#導入)を参照してください。

piパッケージはClaude ACP実行環境、shimon、[pi-rewind](https://github.com/arpagon/pi-rewind)の検証済み修正版を含みます。Chromium本体、外部サービスのAPIキー、Claudeの認証情報は自動導入しません。

piでは6スキル、文字ベースのヘッダー、[shimon](https://github.com/hayashiii-ghub/shimon)の`shimon_verify`、`/rewind`がまとめて読み込まれます。`/hikizan`でヘッダーの表示を切り替え、`/shimon`でshimonの実行状態を確認できます。

## 巻き戻し

`/rewind`はGitリポジトリ内で利用でき、チェックポイントを選んでファイル、会話、または両方を巻き戻せます。ファイルを戻す前に現在状態の安全用チェックポイントと差分プレビューを作り、Gitの現在の`HEAD`は動かしません。安全用チェックポイントやプレビューを作れない場合は復元を中止します。

## スキルの指定

piでは`/tansaku`、`/sekkei`、`/jikkou`、`/sadoku`、`/teishutsu`、`/houkoku`から各スキルを直接使えます。標準の`/skill:<name>`も引き続き利用できます。

## Claudeへの委譲

Claude Codeへ独立した意見を求める場合は、`/delegate claude <依頼>`または`delegate_claude`ツールを使います。ACP経由の一回限り・読み取り専用の実行で、通常の作業はpiのままです。

委譲時は現在のPiセッションから利用者とアシスタントの表示テキストおよび要約を最大30,000文字までClaudeへ渡し、内部思考、画像、ツール呼び出し・結果、過去のClaude委譲結果は除外します。委譲セッションで利用できるのは`Read`、`Glob`、`Grep`だけで、対象リポジトリのClaude設定からフック、MCP、追加ツールを持ち込みません。

先にClaude CodeをPro / Maxアカウントでログインしてください。モデルと思考量はClaude Codeの設定を引き継ぎ、モデルだけ変える場合は`HIKIZAN_CLAUDE_MODEL=opus pi`のように指定できます。

`ANTHROPIC_API_KEY`などAPI課金・外部プロバイダーへ切り替える環境変数がある場合は、意図しない従量課金を避けるため委譲を停止します。

## Web検索

ExaのAPIキーを設定してpiを起動すると、追加設定なしで任意の`web_search`も使えます。キーがなければ検索ツール自体を登録せず、従来のhikizanとして動作します。

```bash
read -s EXA_API_KEY
export EXA_API_KEY
pi
```

APIキーの入力内容は画面へ表示されません。macOSでは、キーをコピーして`EXA_API_KEY="$(pbpaste)" pi`でも起動できます。

検索語はExaへ送信されますが、APIキー、検索語、結果、利用状況をhikizan側で保存しません。検索は`fast`、既定5件、最大10件、10秒のタイムアウトに固定しています。HTTP 402では再試行や有料サービスへの切り替えをせず停止します。従量課金の上限は、Exa側でAPIキーごとの予算も設定してください。

## 画面の確認

`shimon_verify`は設定ファイルなしで使えます。Chromiumをまだ導入していない環境だけ、初回に次を実行してください。ブラウザー本体はhikizanのインストール時に自動ダウンロードしません。

```bash
npx playwright install chromium
```

起動済みのURLと必要なケースを`shimon_verify`へ渡します。通常は設定ファイルを作らず、高度な状態再現が必要で、信頼できる既存設定がある場合にその設定を使います。`pass`と各検査に加え、返された画像を`intent`と`review`に沿って確認します。`visualReviewRequired: true`は、画像の確認が必要という意味です。

## 単体パッケージからの移行

以前にshimonを単体のpiパッケージとして導入している場合は、`pi list`でshimonのsourceを確認し、`pi remove <source>`で外してからhikizanを更新してください。同じ`shimon_verify`を2つのパッケージから登録するとpiが起動を拒否します。

以前にpi-rewindを単体導入している場合も、`pi list`でsourceを確認し、`pi remove <source>`で外してからhikizanを更新してください。hikizanは`/rewind`を内蔵します。

## 本番操作の確認

公開やデプロイなど、本番・公開環境に影響しやすいbashコマンドは実行直前に確認します。非対話モードでは対象コマンドを停止します。この確認は権限境界ではないため、操作を強制的に制限する場合はリポジトリや配布先の保護規則を使います。

登録条件と失敗時の扱いは[フックの責務](../../conditions.md)を参照してください。
