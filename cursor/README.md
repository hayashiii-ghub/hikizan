# cursor/ — Cursor 向け floors adapter

Cursor の `beforeShellExecution` hook に hikizan の floors (保護 branch への force push → deny、不可逆操作 → ask) を移植した adapter。背景・評価・限界は `docs/cursor-floors.md` を参照。

## install

1. hikizan repo を clone する (`npx skills add` は skills/ しか配置しないため、floors は repo から直接参照する)。
2. `~/.cursor/hooks.json` (user) または `<project>/.cursor/hooks.json` に登録する。**`command` は本 repo 内 `cursor/scripts/before-shell.sh` の絶対パスにする** — 同梱の `cursor/hooks.json` は形を示すテンプレで、相対パスのままでは動かない:

   ```json
   {
     "version": 1,
     "hooks": {
       "beforeShellExecution": [
         { "command": "/abs/path/to/hikizan/cursor/scripts/before-shell.sh" }
       ]
     }
   }
   ```

3. `jq` が必要 (CC hooks と同じ)。
4. script は repo 内の `hooks/scripts/lib/` を相対参照するため、`cursor/` ディレクトリ単体をコピーしての利用は不可 (repo ごと置く)。

## 注意

- **実 Cursor 環境での live 検証は未実施** (glue は `hooks/tests/test-cursor-floors.sh` で検査済み)。導入後、deny / ask が 1 度発火することを目視してから常用すること。
- 判定ロジックは CC hooks と同一ファイル (`hooks/scripts/lib/push-parse.sh` / `destructive.sh`) を再利用しており、head / subcommand に anchored — 引用文字列内の `--force` 等では発火しない。
- floors を入れた環境は `HIKIZAN_TIER=standard` を宣言してよい (`docs/cursor-floors.md`「tier への含意」)。
