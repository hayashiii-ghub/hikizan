# AGENTS.md

この repo は **hikizan** plugin / skill pack 本体です。作業時はこのファイルを入口にし、詳細は該当する SoT に従う。

## Routing


| やること                                     | SoT                                                    |
| ---------------------------------------- | ------------------------------------------------------ |
| skill の trigger / mode / 出力形式 / 停止条件を変える | `skills/<name>/SKILL.md`                               |
| skill discovery の条件を変える                  | 各 `skills/<name>/SKILL.md` の frontmatter `description` |
| skill 間 handoff を変える                     | `docs/workflow.md` §7                                  |
| PR / branch / step の命名規約を変える             | `skills/kouchiku/SKILL.md` Hard Rules                  |
| 引き算原則を変える                                | `skills/kouchiku/references/minimal-approach.md`       |
| review / 整理観点を変える                        | `skills/sadoku/SKILL.md`                               |
| PR 本文ドラフト / PR 提出フローを変える                 | `skills/teishutsu/SKILL.md`                            |
| hook の block / warning 条件を変える            | `hooks/conditions.md` と `hooks/hooks.json`             |
| 利用先 project に注入する常時ロード文を変える              | `templates/CLAUDE.md`                                  |
| 人間向け説明 / install / 公開情報を変える              | `README.md`                                            |


## Rules

- skill 本体 (`skills/`) はハーネス agnostic に書く。Claude Code / Cursor / Codex 等の固有 API 名は、必要な注釈以外では本文に出さない。
- `when_to_use` は非標準の補助メモとして短く残す。発動条件の正本は frontmatter `description`。
- `AGENTS.md` / `templates/CLAUDE.md` に skill の手順、出力形式、hook 条件を再掲しない。
- skill の frontmatter `description` (trigger) を変えたら、それを転記している箇所 (`templates/CLAUDE.md` Routing、`docs/workflow.md` §6 / §7、`README.md` trigger 早見表) が古くないか確認する。
- 破壊的操作や force push は、ユーザの明示確認なしに進めない。
- 設計原則を skill 本文から参照するときは番号でなく名前で書く。

