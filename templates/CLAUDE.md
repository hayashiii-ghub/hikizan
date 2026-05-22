## hikizan Conventions

このセクションは hikizan plugin の基本 routing / safety です。詳細な判断は skill、block / warning は hook に従う。

### Routing

- 設計判断 / 計画 / 実装 / バグ調査は `kouchiku`
- TDD / 回帰テストが必要な実装は `shiken`
- code review / 整理観点の確認は `sadoku`
- PR 本文ドラフト / PR 提出は `teishutsu`

### Safety

- 破壊的操作は、ユーザの明示確認なしに進めない
- submodule を含む repo では、cwd と対象 repo を確認してから PR / commit / push に進む
