# 開発ガイド

## 構成

このリポジトリはhikizanスキルパック本体です。`skills/`はスキル、`hooks/`は任意の実行時連携、`scripts/`は開発用の生成・検査を扱います。ハーネス固有の処理は`hooks/adapters/`へ置き、隠しディレクトリ以外の実装直下を増やしません。

## 検証

必須の依存は`bash` / `jq` / `git` / `gh` / `awk`です。`shellcheck`はローカルでは任意、CIでは必須です。

```bash
bash scripts/check-all.sh
```

変更後は関係する生成スクリプトを実行し、最後にこのコマンドで全体を確認します。

## 編集規約

- スキル本文はハーネスに依存させず、別スキルは論理名で参照する
- ディレクトリ、ファイル、スキルIDは英語のASCII識別子を使い、人が読むMarkdownの見出しは日本語にする
- 自作のシェルスクリプトはshebang直後の2行で、何をするかと、なぜ必要かを日本語で書く。特殊な引数がある場合だけ使い方を続ける
- 6スキルは固定工程ではなく独立した観点として扱い、起動条件と変更権限は各`SKILL.md`の`description`を正本にする
- コミット、ブランチ、PRの命名は`skills/teishutsu/references/naming.md`、日本語散文は`skills/houkoku/references/writing-style.md`に従う

## 生成元

| 変更対象 | 編集するファイル | 反映コマンド |
| --- | --- | --- |
| 共通ルール | `scripts/contract.md` | `bash scripts/gen-contract.sh` |
| スキルの集合・順序 | `scripts/skills.json` | 関係する生成スクリプト |
| 起動規則とREADME一覧 | 各`SKILL.md`の`description` | `bash scripts/gen-routing.sh` / `bash scripts/gen-trigger-docs.sh` |
| ハーネス別マニフェスト | `plugin.src.json` | `bash scripts/gen-manifests.sh` |
| Shimonの共通規則 | `scripts/visual-contract.md` | `bash scripts/gen-visual-contract.sh` |

生成先のマーカー区間と3つの`plugin.json`は直接編集しません。

## フック

フックは、スキル選択規則の注入、起動時のGit状態確認、PRマージの明示承認だけを扱います。正確な条件は`hooks/conditions.md`、共通処理は`hooks/scripts/`、ハーネス差分は`hooks/adapters/`、回帰検査は`hooks/tests/`に置きます。コミット判断、会話回数による内省、利用状況計測は追加しません。

## 安全

- 破壊的操作や強制プッシュは利用者の明示確認なしに進めない
- PR本文とコミットメッセージの秘密情報検査は`skills/teishutsu/references/pr-template.md`に従う
- 実行可能Markdownはコードとしてレビューする
