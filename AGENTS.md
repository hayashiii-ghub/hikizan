# 開発ガイド（AGENTS.md）

## 概要

このリポジトリはhikizanスキルパック本体です。実行物は`skills/`と任意の`hooks/`、開発用ツールは`scripts/`に置きます。ハーネス固有の設定を直下へ増やさず、各ハーネスのマニフェストから`hooks/adapters/`を参照します。プラグインでは、スキルを見つけやすくする短い起動規則も配布します。

## 検証

必須の依存は`bash` / `jq` / `git` / `gh` / `awk`です。静的解析の`shellcheck`はローカルでは任意、CIでは必須です。

```bash
bash scripts/check-all.sh
```

これがフックテスト、操作手順の回帰検査、整合性検査、生成物の鮮度確認、`shellcheck`の単一入口です。フック単体実行より`hooks/tests/run.sh`を優先します。

## 規約

- スキル本文はハーネスに依存させない。Claude Code / Cursor / Codex固有のAPIは必要な注釈以外で本文に出さない
- ディレクトリ・ファイル・スキルIDは英語のASCII識別子を使い、人が読むMarkdownの見出しは日本語話者が内容を判断できる日本語にする
- 配布単位はパック全体だが、6スキルは固定順の工程ではなく独立した観点として使う。依頼に終点があれば必要なスキルをつなぎ、明示済みの終点まで形式的な承認待ちを追加しない
- 明確で可逆な作業は同じ依頼内で完了し、確認・検証・レビューは不可逆性、外部作用、セキュリティ、データ、公開インターフェース、取り消し費用に比例させる
- 別スキルを参照するときは論理名を使い、リポジトリ相対のパスを使わない
- 共通契約の正本は`scripts/contract.md`。各`SKILL.md`の契約マーカー間を直接編集しない
- スキル起動時の`🌲`表示は共通契約で揃え、同じスキル内の局所作業では繰り返さない
- 中核スキルの集合・表示順の正本は`scripts/skills.json`
- 起動条件表は`scripts/gen-trigger-docs.sh`で生成し、READMEのマーカー区間を手動編集しない
- ハーネスへ渡す起動規則は`scripts/gen-routing.sh`で生成し、`hooks/routing.md`とCursor向け規則を手動編集しない
- マニフェスト情報の正本は`plugin.src.json`。3つの`plugin.json`は`scripts/gen-manifests.sh`の生成物
- 視覚検証の共通規則の正本は`scripts/visual-contract.md`
- コミット・ブランチ・PRの命名は`skills/teishutsu/references/naming.md`
- 日本語散文は`skills/houkoku/references/writing-style.md`
- 隠しディレクトリ以外の実装直下を`skills/` / `hooks/` / `scripts/`以外に増やさない

スキルを足す・減らす場合：

1. `skills/<name>/SKILL.md`と必要な参照資料を変更
2. `scripts/skills.json`を更新
3. `bash scripts/gen-contract.sh`
4. `bash scripts/gen-routing.sh`
5. `plugin.src.json`の説明文テンプレートを確認し、`bash scripts/gen-manifests.sh`
6. `bash scripts/gen-trigger-docs.sh`
7. `bash scripts/check-all.sh`

## 安全フック

安全フックはプッシュ、PR作成、破壊的なシェル操作の決定論的な安全下限だけを扱います。正確な条件は`hooks/conditions.md`を正本とします。これとは別に、起動時アダプターは生成済みの短いスキル選択規則だけを渡します。

- 共通分類は`hooks/scripts/lib/`と`hooks/scripts/pre-*.sh`に置き、ハーネス差分は`hooks/adapters/`の入出力と判定方針だけにする
- Claudeの入口は`hooks/hooks.json`、回帰検査は`hooks/tests/`
- コミット判断、会話回数による内省、一般的な文脈注入、利用状況計測は追加しない。起動時に渡せるのは`hooks/routing.md`のスキル選択規則だけとする

## 安全

- 破壊的操作や強制プッシュは利用者の明示確認なしに進めない
- PR本文・コミットメッセージへトークン、メールアドレス、チーム外の実名を書かない。検査手順は`skills/teishutsu/references/pr-template.md`
- 実行可能Markdownはコードとしてレビューし、シェルの安全性、一時ファイル、後処理、ネットワーク境界も確認する

## 正本

| 変更対象 | 正本 |
| --- | --- |
| スキルの起動条件・使い分け・出力・停止条件 | `skills/<name>/SKILL.md` |
| スキルの共通契約 | `scripts/contract.md` |
| スキルの集合・順序 | `scripts/skills.json` |
| ハーネス共通の起動規則 | 各`SKILL.md`の`when_to_use` / `scripts/gen-routing.sh` |
| 探索・影響範囲・任意のドメイン文書化 | `skills/tansaku/` |
| 設計・計画・原則 | `skills/sekkei/` |
| 実装・診断・コミット境界 | `skills/jikkou/` |
| レビュー・簡略化・専門レビューの指示 | `skills/sadoku/` |
| PR・命名・秘密情報検査 | `skills/teishutsu/` |
| README・技術文書・記事・推敲・Slack・リリース・引き継ぎと日本語文章規範 | `skills/houkoku/` |
| UI視覚検証・Shimon利用契約 | `scripts/visual-contract.md` |
| フック分類とアダプター | `hooks/conditions.md` / `hooks/scripts/` / `hooks/adapters/` |
| バージョン・作者・ハーネス別の説明 | `plugin.src.json` |
| Claudeマーケットプレイスの公開概要 | `.claude-plugin/marketplace.json` |
| 人間向けの導入・公開情報 | `README.md` |
