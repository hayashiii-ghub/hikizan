# hikizan hooks: stop condition matrix

Claude Code plugin の hooks で監視する条件 / 挙動 / 終了コードの一覧。実体は同階層の `hooks.json` と `scripts/` を参照。

## マトリクス

| event | matcher / if | 条件 | 挙動 | exit |
|---|---|---|---|---|
| SessionStart | matcher `startup` | プロジェクト直下に `CLAUDE.md` が無い、または「## hikizan Conventions」が無い | テンプレを生成または追記 (冪等) | 0 |
| PreToolUse | `Bash(git push*)` | local が remote から N コミット遅れている (non-fast-forward) | stderr に選択肢 (pull --rebase / 別 branch / abort) を提示して block | 2 |
| PreToolUse | `Bash(git push*)` | `--force` / `--force-with-lease` が main / master / develop に対して指定 | stderr に確認要求 → block | 2 |
| PreToolUse | `Bash(gh pr create*)` | `--draft` も `--reviewer` も無い | stderr に「draft 化 / reviewer 指定 / 明示確認」を提示して block | 2 |
| PostToolUse | `Bash(git commit*)` | submodule pointer 変更ありで submodule 側が未 push | stderr に warning を出力 (block しない) | 0 |

## 設計判断

- **block するのは PreToolUse のみ**。PostToolUse は副作用が完了済みなので block しても巻き戻せず、warning に留める
- **選択肢は stderr に文章で出す**。CC は hook stderr を Claude (本体) に error message として渡すので、Claude が次のメッセージでユーザに選択肢を提示する。`permissionDecision: ask` (yes/no ダイアログ) は N 択 (force / merge / abort 等) を表現できないため不採用
- **判定は local 情報優先**。`git fetch --quiet` は走らせるが失敗時はスルー、ローカル状態だけで判定継続。hook が外部依存で死ぬのを避ける
- **保護 branch は main / master / develop の 3 つで固定**。プロジェクトごとの拡張は将来 `.claude-plugin/config.json` 等で外出しできるが、現状は YAGNI

## メトリクス記録

書き込み先: `~/.hikizan/metrics.jsonl` (環境変数 `HIKIZAN_METRICS_DIR` で上書き可、append only)。
実装: `scripts/lib/metrics.sh` の `hikizan_metrics_log` 関数を各 hook が source して呼ぶ。silent on failure (jq 不在 / dir 書き込み不可 等で hook 本体は壊さない)。

### スキーマ (1 行 1 JSON event)

```json
{"ts":"2026-05-19T14:46:00Z","event":"hook_fired","hook":"pre-push","condition":"nff","decision":"block","session_id":"abc123"}
```

| field | 値 |
|---|---|
| `ts` | RFC3339 UTC タイムスタンプ |
| `event` | `hook_fired` (将来拡張余地) |
| `hook` | `pre-push` / `pre-pr-create` / `post-commit` / `bootstrap-claude-md` |
| `condition` | `nff` / `force_protected` / `no_draft_no_reviewer` / `submodule_unpushed` / `create` / `append` / `noop` / `none` |
| `decision` | `allow` / `block` / `warn` |
| `session_id` | CC session id (stdin JSON より取得)、無ければ空文字 |

### 集計例

```bash
# 過去 1 週間の block 件数を hook 別に
jq -r 'select(.decision == "block") | .hook' ~/.hikizan/metrics.jsonl | sort | uniq -c

# CLAUDE.md bootstrap の create/append/noop 比率
jq -r 'select(.hook == "bootstrap-claude-md") | .condition' ~/.hikizan/metrics.jsonl | sort | uniq -c
```

ローテーション / 自動 dashboard は未実装 (利用実績が貯まってから別 issue)。

## SessionStart の補足

- CC plugin に **install lifecycle hook が存在しない**ため、CLAUDE.md auto-bootstrap は SessionStart hook の matcher `startup` で実現
- 冪等性: 既に「## hikizan Conventions」セクションがあれば何もしない、無ければテンプレを追記、CLAUDE.md 自体が無ければ生成
- `resume` / `clear` / `compact` では走らない (matcher が `startup` のみ)

## 関連

- `hooks.json` — 実体の hook 設定 (matcher / if / script 紐付け)
- `scripts/bootstrap-claude-md.sh` — SessionStart on `startup` (CLAUDE.md 冪等 bootstrap)
- `scripts/pre-push.sh` — PreToolUse on `git push*`
- `scripts/pre-pr-create.sh` — PreToolUse on `gh pr create*`
- `scripts/post-commit.sh` — PostToolUse on `git commit*`
- `templates/CLAUDE.md` — bootstrap される本文
- `teishutsu` skill — hook と二重構造の人手側 (skill 本文の停止条件として、hook は最後の砦)
