## 共通ルール

core skill (init を除く全 skill) 共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `skills/teishutsu/references/commit.md` の粒度契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は skills/teishutsu/references/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は skills/shippitsu/references/writing-style.md の規範に従う
