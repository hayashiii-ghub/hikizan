## hikizan Conventions

hikizan plugin の基本 routing / safety。詳細な判断は各 skill、block / warning は hook に従う。

### tier

- `hikizan-tier: standard` — Claude Code (hooks = floors あり)。各 skill の invariant を満たす限り「既定手順」は圧縮してよい。
- 宣言が無ければ `guided` (既定手順を遵守)。不可逆・破壊的操作の rails は tier に関わらず守る。

### Routing

- 設計判断 / 計画 / 実装 / バグ調査 → `kouchiku`
- 情報取得 / 全体像把握 / 影響範囲調査 / 用語すり合わせ → `tansaku`
- TDD / 回帰テストが必要な実装 → `shiken`
- code review / 整理観点の確認 → `sadoku`
- PR 本文ドラフト / PR 提出 → `teishutsu`

### Safety

- 破壊的操作は、ユーザの明示確認なしに進めない
- submodule を含む repo では、cwd と対象 repo を確認してから PR / commit / push に進む
