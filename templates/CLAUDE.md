## hikizan Conventions

このセクションは hikizan plugin の最小 router / safety です。詳しい判断は skill、強制的な block / warning は hook に従う。

### Routing

- 設計判断 / 計画 / 実装が必要なときは `kouchiku`
- バグ調査 / 原因不明の失敗は `tansaku`
- TDD / 回帰テストが必要な実装は `shiken`
- code review / 整理観点の確認は `sadoku`
- PR 本文ドラフト / PR 提出は `teishutsu`

### Safety

- 破壊的操作や force push は、ユーザの明示確認なしに進めない
- submodule を含む repo では、cwd と対象 repo を確認してから PR / commit / push に進む
