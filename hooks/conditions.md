# フックの責務

フックは次の処理を扱います。piだけは、画面検証、読み取り専用のClaude ACP委譲、利用者が`EXA_API_KEY`を設定した場合の任意Web検索、本番・公開環境へ影響しやすいbashコマンドの実行前確認も提供します。実装判断、コミット可否、会話回数による内省、利用状況計測は扱いません。

| タイミング | 処理 | 失敗時 |
| --- | --- | --- |
| セッション開始 | 生成済みのスキル選択規則を渡す | 規則を渡せなくても作業を止めない |
| セッション開始 | 現在のリポジトリ、ブランチ、作業ツリー、upstreamとの差分を1行で渡す | リモート取得に失敗した場合は`未確認`とする |
| pi拡張の読込 | `shimon_verify`と`/shimon`を登録する | 単体版shimonとの重複登録があればpiの読込エラーとして扱う |
| pi拡張の読込 | Gitリポジトリ内で`/rewind`と復元前チェックポイントを登録する | 単体版pi-rewindはHikizan更新前に外し、安全用チェックポイントや差分プレビューを作れない復元は中止する |
| pi拡張の読込 | 読み取り専用の`delegate_claude`と`/delegate claude`を登録する | Claudeの認証や課金境界を満たさない場合は委譲だけを停止する |
| pi拡張の読込 | `EXA_API_KEY`がある場合だけExaの`web_search`を登録する | キーがなければ検索機能を登録せず、従来機能だけで続行する |
| piのbash実行前 | 公開、デプロイ、リモートマージ、保護対象へのpush、インフラ変更、共有データのマイグレーションを確認する | TUIがなければ実行を止め、対話モードでの確認を求める |

リモート確認は、設定済みのupstreamに対する`git fetch --no-tags`だけを短時間実行します。作業ツリー、ローカルブランチ、履歴は変更せず、pull、merge、rebase、pruneは行いません。

利用者の依頼に外部変更が含まれるかは`routing.md`の起動規則で判断します。piでは加えて、高確度で本番・公開環境へ影響するコマンドだけを実行直前に確認します。これは権限境界ではないため、本当に操作を強制したい場合は対象リポジトリや配布先の保護規則を使います。

## 構成

- `hooks.json`：Claude Codeの入口
- `adapters/codex/hooks.json`：Codexの入口
- `adapters/cursor/`：Cursorの起動規則とGit状態の入口
- `adapters/pi/index.ts`：piの起動規則、Git状態、TUI、画面検証、Claude ACP委譲、任意Web検索の入口
- `adapters/pi/claude-delegate.ts`：読み取り専用のClaude ACP委譲ツールとコマンド
- `adapters/pi/claude-delegate-runtime.js`：Claude ACPの起動引数、認証・課金環境の停止境界
- `adapters/pi/production-guard.js`：本番・公開環境へ影響しやすいbashコマンドの実行前確認
- `adapters/pi/production-risk.js`：実行前確認の対象コマンド分類
- `adapters/pi/exa-search.ts`：キー設定時だけ登録する`web_search`
- `adapters/pi/exa-client.js`：Exaへの低遅延検索と停止境界
- `scripts/session-routing.sh`：起動時の規則とGit状態
- `tests/`：起動情報と各アダプターの回帰検査
