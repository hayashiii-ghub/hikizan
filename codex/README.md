# Codex 向け floors adapter (codex/)

Codex CLI は v0.117+ で plugin が first-class、v0.128 で plugin 同梱 hooks が GA。入力
(`tool_input.command` / `cwd` / `session_id`) と出力 (`hookSpecificOutput.permissionDecision`) が
Claude Code と完全に同一のため、CC の floor スクリプト (`hooks/scripts/pre-push.sh` /
`pre-destructive.sh` / `pre-pr-create.sh`) を**そのまま再利用**する。Codex 用に複製した判定ロジックは
無い。

## install (plugin、推奨)

repo に marketplace catalog (`.agents/plugins/marketplace.json`) と plugin manifest
(`.codex-plugin/plugin.json`) が同梱されているので、2 コマンドで入る。skills 6 個 + floors hooks +
前文 (SessionStart) が一括で入り、`npx skills add -a codex` も `~/.codex/hooks.json` への絶対パス
手書きも不要:

```bash
codex plugin marketplace add hayashiii-ghub/hikizan
codex plugin install hikizan
```

- 特定 version に固定するなら `codex plugin marketplace add hayashiii-ghub/hikizan --ref v0.7.1`
- TUI 派は 1 行目のあと `/plugins` で marketplace `hikizan` から選んでもよい
- `jq` が必要 (CC / Cursor と同じ)

**実 Codex 環境での plugin ロードは未 live 検証**。特に、repo 直下の `hooks/hooks.json` (CC 用、
`${CLAUDE_PLUGIN_ROOT}` と CC 固有の `if` を使う) を Codex の auto-detect が拾わないことは、
`.codex-plugin/plugin.json` の明示 `hooks` field (`./codex/hooks.json`) が auto-detect を置換する
前提に依存しており、この置換の挙動は docs に明記が無いため未検証。

## install (fallback: 手動 `~/.codex/hooks.json`)

plugin が使えない環境向けの fallback。

1. hikizan repo を clone する (`npx skills add` は skills/ しか配置しないため、floors は repo から
   直接参照する)。
2. `~/.codex/hooks.json` (または `<repo>/.codex/hooks.json`。`config.toml` でも可) に登録する。
   **`command` は本 repo 内スクリプトの絶対パスにする**。同梱の `codex/hooks.json` は plugin 経由の
   `${PLUGIN_ROOT}` 版のため、手動 install では下記のような絶対パス版に置き換える:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             { "type": "command", "command": "/abs/path/to/hikizan/hooks/scripts/pre-push.sh", "statusMessage": "checking push preconditions..." },
             { "type": "command", "command": "/abs/path/to/hikizan/hooks/scripts/pre-destructive.sh", "statusMessage": "checking destructive op..." },
             { "type": "command", "command": "/abs/path/to/hikizan/hooks/scripts/pre-pr-create.sh", "statusMessage": "checking PR create preconditions..." }
           ]
         }
       ],
       "SessionStart": [
         {
           "matcher": "startup|resume",
           "hooks": [
             { "type": "command", "command": "/abs/path/to/hikizan/codex/scripts/session-context.sh" }
           ]
         }
       ]
     }
   }
   ```

3. `jq` が必要 (CC / Cursor と同じ)。
4. skill 本体は `npx skills add github:hayashiii-ghub/hikizan -g -a codex` で別途配置する (floors とは
   独立。skill pack だけ入れて floors を入れない、逆に floors だけ入れることもできる)。

## floors

CC と同一ロジックの 3 つ:

- force push / 保護 branch (main / master / develop) への force-equivalent push → `deny`
- 破壊的操作 (`rm -rf` / `git reset --hard` / `git clean -f` / `git checkout` の破棄的形) → `ask`
- `gh pr create` を `--draft` も `--reviewer` も無しで実行 → `deny`

matcher は tool 名の regex (CC の `if` prefix のような per-hook 条件は無い) なので、3 スクリプトを
`Bash` 全件に配線し、各スクリプトが自分の対象外なら exit 0 する (self-anchor)。

## SessionStart / 前文

`codex/scripts/session-context.sh` は CC の `session-context.sh` と単一ソース (`templates/routing.md` +
`templates/standard-preamble.md`) を共有し、出力の envelope だけ Codex 形式
(`{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}`) にしたもの。
`HIKIZAN_TIER=standard` (既定) では routing/ルールに加えて opt-out 前文が additionalContext に入る。
`HIKIZAN_TIER=guided` では前文は入らない。

## 既知の限界

CC hooks と同じ (`../hooks/conditions.md` の「既知の限界」を参照)。
