# hikizan hooks: stop condition matrix

Claude Code plugin の hooks で監視する条件 / 挙動 / 終了コードの一覧。実体は同階層の `hooks.json` と `scripts/` を参照。

## マトリクス

| event | matcher / if | 条件 | 挙動 | exit |
|---|---|---|---|---|
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

メトリクス書き出しは未実装。Phase 0 step 0-3 で `~/.hikizan/metrics.jsonl` の append schema を確定したら、各 hook script から書き込み始める (event=hook_fired, hook_name, condition, exit_code, timestamp)。

## 関連

- `hooks.json` — 実体の hook 設定 (matcher / if / script 紐付け)
- `scripts/pre-push.sh` — PreToolUse on `git push*`
- `scripts/pre-pr-create.sh` — PreToolUse on `gh pr create*`
- `scripts/post-commit.sh` — PostToolUse on `git commit*`
- Phase 5 `teishutsu` skill — hook と二重構造の人手側 (skill 本文の停止条件として、hook は最後の砦)
