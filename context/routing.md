<!-- hikizan:conventions:start -->
## hikizan Conventions

hikizan plugin の使い方。手順の詳細は各 skill に書いてある。止めるべき操作は hook が止める。

### どの skill を使うか

- 何かを調べる / 全体像を掴む / 影響範囲を知る → `tansaku`
- 設計を決める / 計画を立てる / やる価値を評価する → `sekkei`
- 計画を実行する / バグの原因を探す / ロジックの実装・バグ修正 (テスト先行) → `jikkou`
- diff をレビューする / コード整理の観点を出す → `sadoku`
- PR 本文を書く / PR を出す → `teishutsu`
- 日本語の文章を書く / 推敲する → `shippitsu`

### ルール

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- PR は `teishutsu` の形式で出す (Workflow 節と検証ログを含む)
- submodule のある repo では、commit / push / PR の前に `pwd` と対象 repo を確認する
<!-- hikizan:conventions:end -->
