# 安全フックの判定条件

安全フックは、スキルを経由しないシェル操作にも適用する任意の安全下限です。実装判断、会話回数による内省、コミット可否、一般的な文脈注入、利用状況計測は扱いません。プラグインの起動時アダプターは別責務として、生成済みの`hooks/routing.md`だけを渡します。

| 分類 | 条件 | Claude Code / Cursor | Codex / OpenCode |
| --- | --- | --- | --- |
| プッシュ | `main` / `master` / `develop`への強制相当プッシュ、またはリモートより遅れたブランチのプッシュ | `deny` | `deny` |
| 破壊的操作 | `rm -rf`、`git reset --hard`、`git clean -f`、変更破棄を伴う`git checkout` | `ask` | `deny` |
| PR作成 | `gh pr create`に`--draft`も`--reviewer`もない | `deny` | `deny` |

CodexとOpenCodeはフックから対話的な`ask`を返せないため、破壊的操作も`deny`にします。拒否後にエージェントが別経路で回避してはならず、必要なら利用者本人へ実行を戻します。

## 構成

- `hooks.json`：Claude Codeの固定入口
- `adapters/codex/hooks.json`：Codexのマニフェストから参照する配線
- `adapters/cursor/hooks.json` / `before-shell.sh`：Cursorの入出力アダプター
- `adapters/opencode/hikizan.ts`：OpenCodeの`tool.execute.before`アダプター
- `scripts/pre-*.sh`：共通入口
- `scripts/lib/`：シェル解析、分類、判定形式
- `tests/`：共通ロジックと各アダプターの回帰テスト

全ハーネスは同じ分類ロジックを共有し、差分は入力形式と判定方針だけに限定します。フックは補助的な安全策であり、すべてのシェル経路を捕捉するセキュリティ境界とはみなしません。
