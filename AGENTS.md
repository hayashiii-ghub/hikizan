# AGENTS.md

## Overview

このrepoはhikizan skill pack本体。runtimeは`skills/`と任意の`hooks/`、開発toolingは`scripts/`。ハーネス固有の設定をrootへ増やさず、native manifestから`hooks/adapters/`を参照する。

## Setup and test

core依存は`bash` / `jq` / `git` / `gh` / `awk`。静的解析の`shellcheck`はlocalでは任意、CIでは必須。

```bash
bash scripts/check-all.sh
```

これがhook tests、recipe regression、consistency、生成物鮮度、shellcheckの単一入口。hook単体実行より`hooks/tests/run.sh`を優先する。

## Conventions

- skill本文はハーネス非依存にする。Claude Code / Cursor / Codex固有APIは必要な注釈以外で本文に出さない
- 配布単位はpack全体。別skillは論理名で参照し、repo-relative pathを使わない
- shared contractの正本は`scripts/contract.md`。各SKILL.mdのcontract marker間を直接編集しない
- core skill集合・表示順の正本は`scripts/skills.json`
- trigger表は`scripts/gen-trigger-docs.sh`で生成し、READMEのmarker区間を手動編集しない
- manifest metadataの正本は`plugin.src.json`。3つのplugin.jsonは`scripts/gen-manifests.sh`の生成物
- visual verification共通規則の正本は`scripts/visual-contract.md`
- commit / branch / PRの命名は`skills/teishutsu/references/naming.md`
- 非hiddenの実装rootを`skills/` / `hooks/` / `scripts/`以外に増やさない

skillを足す・減らす場合:

1. `skills/<name>/SKILL.md`と必要なreferencesを変更
2. `scripts/skills.json`を更新
3. `bash scripts/gen-contract.sh`
4. `plugin.src.json`のdescription templateを確認し`bash scripts/gen-manifests.sh`
5. `bash scripts/gen-trigger-docs.sh`
6. `bash scripts/check-all.sh`

## Hooks

hooksはpush、PR作成、破壊的shell操作の決定論的なfloorだけを扱う。commit判断、会話回数ベースの内省、context注入、metricsは追加しない。

- 発火条件: `hooks/conditions.md`
- Claude entrypoint: `hooks/hooks.json`
- Codex / Cursor配線: `hooks/adapters/`
- 共通logic: `hooks/scripts/lib/`と`hooks/scripts/pre-*.sh`
- 回帰検査: `hooks/tests/`

force pushとreviewerなしの非draft PR作成は全対応ハーネスでdeny。破壊的操作はClaude Code / Cursorでask、askを返せないCodexではdeny。差分はadapterのI/Oとdecision policyに限定する。

## Safety

- 破壊的操作やforce pushはユーザの明示確認なしに進めない
- PR本文・commit messageへtoken、email、チーム外の実名を書かない。scan recipeは`skills/teishutsu/references/pr-template.md`
- 実行可能Markdownはcodeとしてreviewし、shell safety、temporary file、cleanup、network境界も確認する

## Routing

| 変更対象 | SoT |
| --- | --- |
| skill trigger / mode / output / stop condition | `skills/<name>/SKILL.md` |
| 共通skill contract | `scripts/contract.md` |
| skill集合・順序 | `scripts/skills.json` |
| 探索・用語・CONTEXT.md契約 | `skills/tansaku/` |
| 設計・計画・原則 | `skills/sekkei/` |
| 実装・診断・commit境界 | `skills/jikkou/` |
| review・simplify・reviewer prompts | `skills/sadoku/` |
| PR・命名・秘密情報scan | `skills/teishutsu/` |
| hook分類とadapter | `hooks/conditions.md` / `hooks/scripts/` / `hooks/adapters/` |
| version / author / harness description | `plugin.src.json` |
| Claude marketplaceの公開概要 | `.claude-plugin/marketplace.json` |
| 人間向けinstall・公開情報 | `README.md` |
