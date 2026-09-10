# フックの責務

実行時に追加する処理の正本です。利用者向けのコマンドと設定は[piの案内](adapters/pi/README.md)、編集規約と検証は[開発ガイド](../AGENTS.md)を参照してください。

## 環境との接続

| 環境 | 接続 |
| --- | --- |
| Claude Code | `hooks.json`から共通の起動スクリプトを呼ぶ |
| Codex | `adapters/codex/hooks.json`から同じスクリプトを呼ぶ |
| Cursor | `adapters/cursor/rules/hikizan.mdc`で規則を渡す |
| pi | 標準のスキル検出を使い、`adapters/pi/index.ts`で追加機能を登録する |

起動スクリプトは生成済みの`routing.md`を渡すだけで、Git確認やfetchは行いません。piは選択規則を重ねて注入せず、独自の進行ステータスも表示しません。

## 登録と失敗時の動作

| タイミング | 処理 | 失敗時 |
| --- | --- | --- |
| Claude Code・Codexのセッション開始 | 生成済みのスキル選択規則を渡す | 規則を渡せなくても作業を止めない |
| pi拡張の読込 | `shimon_verify`と`/shimon`を登録する | 単体版shimonとの重複登録があればpiの読込エラーとして扱う |
| pi拡張の読込 | Gitリポジトリ内で`/rewind`と復元前チェックポイントを登録する | 単体版pi-rewindはHikizan更新前に外し、安全用チェックポイントや差分プレビューを作れない復元は中止する |
| pi拡張の読込 | 読み取り専用の`delegate_claude`と`/delegate claude`を登録する | Claudeの認証や課金境界を満たさない場合は委譲だけを停止する |
| pi拡張の読込 | `EXA_API_KEY`がある場合だけExaの`web_search`を登録する | キーがなければ検索機能を登録せず、従来機能だけで続行する |
| piのbash実行前 | 公開、デプロイ、リモートマージ、保護対象へのpush、インフラ変更、共有データのマイグレーションを確認する | TUIがなければ実行を止め、対話モードでの確認を求める |

piの本番操作確認は権限境界ではありません。対象コマンドの判定は`adapters/pi/production-risk.js`、確認は`adapters/pi/production-guard.js`が扱います。権限の強制は対象リポジトリや配布先の保護規則で行います。

Claude委譲の認証・課金条件は`adapters/pi/claude-delegate-runtime.js`、Exaへの接続と停止条件は`adapters/pi/exa-client.js`にあります。
