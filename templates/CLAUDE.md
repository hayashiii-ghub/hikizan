## hikizan Conventions

このリポジトリで hikizan plugin を使うときの常時ロード用ルール。SessionStart hook が CLAUDE.md にこのセクションを追記する。手動で書き換えても再走時に重複追記はされない。

このファイルは安全帯だけを持つ。詳しい手順は該当 skill と hook の正本に従う。

### Routing

- 設計判断 / 計画 / 実装が必要なときは `kouchiku`
- バグ調査 / 原因不明の失敗は `tansaku`
- TDD / 回帰テストが必要な実装は `shiken`
- code review / PR 説明文 / 整理観点の確認は `sadoku`
- PR 提出は `teishutsu`

### Safety

- 命名 / 計画 / review / PR 提出の詳細は該当 skill に従う
- push / PR 作成 / commit 後の警告や block は hikizan hooks に従う
- 破壊的操作や force push は、ユーザの明示確認なしに進めない
- submodule を含む repo では、cwd と対象 repo を確認してから PR / commit / push に進む
