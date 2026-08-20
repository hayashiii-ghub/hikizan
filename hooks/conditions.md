# フックの責務

フックは次の起動処理を扱います。piだけは、利用者が`EXA_API_KEY`を設定した場合に限り、任意のWeb検索も提供します。実装判断、コミット可否、外部操作の承認、会話回数による内省、利用状況計測は扱いません。

| タイミング | 処理 | 失敗時 |
| --- | --- | --- |
| セッション開始 | 生成済みのスキル選択規則を渡す | 規則を渡せなくても作業を止めない |
| セッション開始 | 現在のリポジトリ、ブランチ、作業ツリー、upstreamとの差分を1行で渡す | リモート取得に失敗した場合は`未確認`とする |
| pi拡張の読込 | `EXA_API_KEY`がある場合だけExaの`web_search`を登録する | キーがなければ検索機能を登録せず、従来機能だけで続行する |

リモート確認は、設定済みのupstreamに対する`git fetch --no-tags`だけを短時間実行します。作業ツリー、ローカルブランチ、履歴は変更せず、pull、merge、rebase、pruneは行いません。

PRマージと既定ブランチへの直接のpushはコマンド解析で止めず、`routing.md`の起動規則として扱います。本当に操作を強制したい場合は、対象リポジトリ側の保護規則を使います。

## 構成

- `hooks.json`：Claude Codeの入口
- `adapters/codex/hooks.json`：Codexの入口
- `adapters/cursor/`：Cursorの起動規則とGit状態の入口
- `adapters/pi/index.ts`：piの起動規則、Git状態、TUI、任意Web検索の入口
- `adapters/pi/exa-search.ts`：キー設定時だけ登録する`web_search`
- `adapters/pi/exa-client.js`：Exaへの低遅延検索と停止境界
- `scripts/session-routing.sh`：起動時の規則とGit状態
- `tests/`：起動情報と各アダプターの回帰検査
