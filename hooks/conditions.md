# Safety floors

hooksはskillを経由しないshell操作にも適用する任意の安全下限。実装判断、会話回数による内省、commit可否、context注入、利用状況計測は扱わない。

| 分類 | 条件 | Claude Code / Cursor | Codex |
| --- | --- | --- | --- |
| push | `main` / `master` / `develop`へのforce相当push、またはremoteより遅れたbranchのpush | deny | deny |
| destructive | `rm -rf`、`git reset --hard`、`git clean -f`、変更破棄を伴う`git checkout` | ask | deny |
| PR create | `gh pr create`に`--draft`も`--reviewer`もない | deny | deny |

Codexはhookから対話的な`ask`を返せないため、破壊的操作もdenyする。deny後にagentが別経路で回避してはならず、必要ならuser本人へ実行を返す。

## 構成

- `hooks.json`: Claude Codeの固定entrypoint
- `adapters/codex/hooks.json`: Codex manifestから参照する配線
- `adapters/cursor/hooks.json` / `before-shell.sh`: CursorのI/O adapter
- `scripts/pre-*.sh`: 共通entrypoint
- `scripts/lib/`: shell解析、分類、decision envelope
- `tests/`: shared logicと各adapterの回帰テスト

全ハーネスは同じ分類ロジックを共有し、差分は入力形式とdecision policyだけに限定する。hookは補助guardrailであり、すべてのshell経路を捕捉するsecurity boundaryとはみなさない。
