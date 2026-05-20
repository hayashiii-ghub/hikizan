## hikizan Conventions

このリポジトリで hikizan plugin を使うときの作業ルール。plugin install 時に SessionStart hook が CLAUDE.md にこのセクションを追記する (冪等)。手動で書き換えても再走時に重複追記はされない。

### 計画段階の 4 ステッププロトコル

発話トリガー: 「確度高い計画」

1. **不足情報の洗い出し**: 確度を下げている要素を列挙
2. **ユーザ確認 → ダメなら推測**: hikizan kouchiku の Phase 0 走査 (周辺コードから確度% 付き推測) で代替可
3. **issue 文に立ち返って引き算**: issue 文に書かれていない設計を「拾いに行った余計」と仕分け
4. **ミニマル計画を提示**: 規模 (ファイル数 / 行数 / PR 数)

### 命名規約

- PR / branch / step を独自連番 (PR-1 等) で呼ばない。issue 名 / 機能名 / branch 名で呼ぶ
- 重複時のみ `-v2`, `-v3`, `-v4` ... のサフィックス (バージョン番号として。`-alt` は使わない)

### レビュー指摘の defer 判断

- 修正コスト × リスク × 別 issue 値 の 3 軸で個別判断
- low severity は default で「実装中に分かったこと」に記録のみ
- finding template の `disposition` / `disposition_reason` フィールドに必ず書く (詳細は hikizan sadoku simplify findings)

### リモート操作の原則

- push 前に `git fetch --all` で衝突確認 (hikizan の pre-push hook が non-fast-forward を自動検出して block する)
- non-fast-forward 衝突時は破壊的修復 (`git push --force`) を default にしない
- 別ブランチで両案を残すことを検討する
- `main` / `master` / `develop` への force push は pre-push hook が必ず block する

### submodule 含む repo での gh コマンド

- cwd を明示的に確認してから `gh pr create` / `gh pr comment` を走らせる
- `gh pr create` は `--repo` オプションで対象を固定するのが安全
- 親 commit に submodule pointer 変更があるなら submodule を先に push (hikizan の post-commit hook が submodule 未 push を警告)

### 引き算プロトコル

通常検討モードの計画策定では出力に `Minimal Approach:` セクションを必ず添える:

- issue 文の動詞 / 名詞句から素直な規模 (ファイル数 / 行数 / step 数) を概算
- plan が素直な規模の **2 倍以上** → 引き算した最小版を併記、defer 項目を明示
- **2 倍未満** → "minimal already" と明記

推奨度は `N/10 + 1 行根拠` の形式で書く (数値だけだと検証不能)。**3 案以上は出さない** (paralysis 防止)。

詳細: hikizan plugin の `skills/kouchiku/references/minimal-approach.md`

### PR 提出フロー

`teishutsu` skill (発話: 「PR出す」「PR提出」「提出して」) が 4 step で運ぶ:

1. リモート状態確認 (`git fetch --all` → 先行 commit がないか)
2. submodule に変更があれば submodule 側から先に commit + push
3. 親 commit は submodule pointer 込みで作成
4. PR 作成 (`gh pr create --draft --reviewer @user` を default、cwd を明示確認してから走らせる)

hikizan の hook (pre-push / pre-pr-create / post-commit) が最後の砦として block / warning を出す。
