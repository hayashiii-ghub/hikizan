# OpenCode adapter

OpenCode向けのhikizan adapter。skillはOpenCode nativeのAgent Skills discovery、floorsとcontext注入は`hikizan.ts`が担当する。

## install

利用時の前提は`bash` / `jq` / `git`。npm packageは未公開のため、cloneしたrepoを参照するlocal pluginとして入れる。

```bash
git clone https://github.com/hayashiii-ghub/hikizan.git
cd hikizan
npx skills add github:hayashiii-ghub/hikizan -g
mkdir -p ~/.config/opencode/plugins
ln -sfn "$(pwd)/opencode/hikizan.ts" ~/.config/opencode/plugins/hikizan.ts
HIKIZAN_ROOT="$(pwd)" opencode
```

継続利用時は、OpenCodeを起動する環境で`HIKIZAN_ROOT`をclone先の絶対pathに設定する。project localで使う場合は`.opencode/plugins/hikizan.ts`へsymlinkしてもよい。skillを`~/.config/opencode/skills/`等へ重複配置しない。

## mapping

| hikizan | OpenCode |
|---|---|
| PreToolUse floors | `tool.execute.before`でshared shell hookを順に実行し、denyを`throw Error`へ変換 |
| PostToolUse metrics | `tool.execute.after`から`post-command.sh`を実行 |
| SessionStart context | `experimental.chat.system.transform`でsession単位にshell結果をcacheし、各system promptへ注入 |

OpenCodeのtool hookは対話的な`ask`決定を返せないため、破壊的操作もCodexと同じくdenyする。`jq`不在やpre hook異常終了はfail-closed。`HIKIZAN_ROOT`が無効な場合はskills-only環境と同じくfail-openする。after hookは観測専用なので、失敗しても完了済みtoolを壊さない。

`experimental.chat.system.transform`は実験的APIであり、OpenCode更新時に互換性確認が必要。npm配布はこのlocal adapterのlive検証後に別途扱う。

検証状態: OpenCode 1.18.0の隔離した`OPENCODE_CONFIG_DIR`でlocal plugin discovery / loadを確認済み。before / after / system hookの振る舞いは結合テスト済みだが、providerを使う実tool callでのfloors発火は未確認。

## test

結合テストには`bun`が必要。

```bash
bash hooks/tests/test-opencode-adapter.sh
bash scripts/check-all.sh
```

実plugin loadの確認には、隔離したOpenCode configで`opencode run`を使う。ユーザの通常configへ直接test pluginを置かない。
