# Cursor 向け floors adapter (cursor/)

Cursor の `beforeShellExecution` hook に hikizan の floors (保護 branch への force push → deny、不可逆操作 → ask) を移植した adapter。加えて `cursor/rules/hikizan.mdc` (always-apply rule) が routing 規約と standard-tier の opt-out 前文を配布する。背景・評価・限界は `docs/cursor-floors.md` を参照。

## install (primary: Cursor plugin)

repo root に `.cursor-plugin/plugin.json` があるため、hikizan repo を Cursor plugin として参照すると floors hooks (`cursor/hooks.json` 経由の `before-shell.sh`) と前文 rule (`cursor/rules/hikizan.mdc`) が自動で入る。手順は Cursor 側の plugin 参照方法に従う (repo を plugin source として登録)。

- `cursor/rules/hikizan.mdc` は `alwaysApply: true` の rule で、常時 context に載る。ここに routing 規約 (`templates/CLAUDE.md`) と standard tier の opt-out 前文 (`templates/standard-preamble.md`) が入っているため、CC の SessionStart hook が届かない Cursor でも opt-out 前文が届く。guided のまま使いたい場合はこの rule を外せばよい (`docs/cursor-floors.md`「tier への含意」)。
- `.cursor-plugin/plugin.json` の `hooks` / `rules` パスは plugin root (= repo root) 相対。

## install (fallback: 手動 hooks.json)

plugin 参照ができない環境向けの手動配線。この場合、前文 rule は自動では届かないため `cursor/rules/hikizan.mdc` を別途 project の rules に置くか、opt-out 無しの guided tier として運用する。

1. hikizan repo を clone する (`npx skills add` は skills/ しか配置しないため、floors は repo から直接参照する)。
2. `~/.cursor/hooks.json` (user) または `<project>/.cursor/hooks.json` に登録する。**`command` は本 repo 内 `cursor/scripts/before-shell.sh` の絶対パスにする**。同梱の `cursor/hooks.json` は plugin 用 (plugin root 相対) で、手動配線ではそのままでは動かない:

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

- **実 Cursor 環境での live 検証は未実施** (glue は `hooks/tests/test-cursor-floors.sh` で検査済み。plugin ロード自体も未検証)。導入後、deny / ask が 1 度発火することを目視してから常用すること。
- 判定ロジックは CC hooks と同一ファイル (`hooks/scripts/lib/push-parse.sh` / `destructive.sh`) を再利用しており、head / subcommand に anchored で、引用文字列内の `--force` 等では発火しない。
- floors を入れた環境は `HIKIZAN_TIER=standard` を宣言してよい (`docs/cursor-floors.md`「tier への含意」)。
- `cursor/rules/hikizan.mdc` は `scripts/gen-cursor-rule.sh` の生成物。手で編集しない (`templates/CLAUDE.md` / `templates/standard-preamble.md` を直す)。
