# Codex 向け plugin adapter (codex/)

Codex plugin として skills、PreToolUse floors、SessionStart 前文をまとめて配る。shell command の分類は
Claude Code / Cursor と同じ `hooks/scripts/lib/` を使い、Codex 固有部分は manifest、hook 配線、出力
envelope に限定する。Codex の PreToolUse は `ask` を扱えないため、破壊的操作だけは同じ分類結果を
`deny` として返す。

## install (plugin、推奨)

repo に marketplace catalog (`.agents/plugins/marketplace.json`) と plugin manifest
(`.codex-plugin/plugin.json`) が同梱されているので、2 コマンドで入る。skills 6 個 + floors hooks +
前文 (SessionStart) が一括で入り、`npx skills add -a codex` も `~/.codex/hooks.json` への絶対パス
手書きも不要:

```bash
codex plugin marketplace add hayashiii-ghub/hikizan
codex plugin add hikizan@hikizan
```

- 特定 version に固定するなら `codex plugin marketplace add hayashiii-ghub/hikizan --ref v0.10.3`
- TUI 派は 1 行目のあと `/plugins` で marketplace `hikizan` から選んでもよい
- `jq` が必要 (CC / Cursor と同じ)
- install 後は表示された hooks の内容を確認して信頼し、新しい task を開始する

Codex CLI 0.144.2 の隔離した `CODEX_HOME` で marketplace 追加、plugin install、一覧表示までは検証済み。
実 tool call での hook 発火と trust UI は未 live 検証。`.codex-plugin/plugin.json` の明示 `hooks`
field (`./codex/hooks.json`) は Codex の既定 hook discovery を置き換えるため、CC 用
`hooks/hooks.json` は読み込まれない。

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
             { "type": "command", "command": "/abs/path/to/hikizan/hooks/scripts/pre-destructive.sh deny", "statusMessage": "checking destructive op..." },
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
- 破壊的操作 (`rm -rf` / `git reset --hard` / `git clean -f` / `git checkout` の破棄的形) → `deny`
- `gh pr create` を `--draft` も `--reviewer` も無しで実行 → `deny`

matcher は tool 名の regex (CC の `if` prefix のような per-hook 条件は無い) なので、3 スクリプトを
`Bash` 全件に配線し、各スクリプトが自分の対象外なら exit 0 する (self-anchor)。

## SessionStart / 前文

`codex/scripts/session-context.sh` は CC の `session-context.sh` と単一ソース (`context/routing.md` +
`context/standard-preamble.md`) を共有し、出力の envelope だけ Codex 形式
(`{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}`) にしたもの。
`HIKIZAN_TIER=standard` (既定) では routing/ルールに加えて opt-out 前文が additionalContext に入る。
`HIKIZAN_TIER=guided` では前文は入らない。

## 既知の限界

floor は補助 guardrail であり、完全な security boundary ではない。特に Codex 側の Bash tool 呼び出し
経路が増えた場合、`matcher: "Bash"` で全 shell execution を捕捉できるとは限らない。分類器自体の限界
(複合 command、対象 command の限定など) と合わせ、`../hooks/conditions.md` の「既知の限界」を参照。

公式仕様:

- [Build plugins](https://developers.openai.com/codex/plugins/build)
- [Plugins](https://developers.openai.com/codex/plugins)
- [Hooks](https://learn.chatgpt.com/docs/hooks)
