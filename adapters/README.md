# adapters/

このディレクトリは Agent Skills 標準でカバーできない特殊ケース用の領域です。**現状は予告のみ**で、実体はまだ入っていません。

## 主な用途

hikizan は (a) Claude Code plugin (`/plugin` 経由) と (b) skill pack (`npx skills add github:hayashiii-ghub/hikizan`) の 2 経路で配布します。両方とも標準仕様の範囲で動くため、ハーネス独自の変換 / 配置スクリプトは通常不要です。

`adapters/` はこの「標準仕様の範囲外」にあるニーズを置く場所です。

## 予定している adapter

- `adapters/codex/` — Claude Code plugin から Codex CLI / SDK を呼び出す adapter。Codex は (b) の skill pack として単独利用もサポートされるが、Claude Code 中心ハーネスから Codex に下請けさせたい場合の橋渡しに使う

## 他に入りうるもの

実需要が出た場合のみ追加:

- 標準仕様外の独自 frontmatter 拡張 (例: ツール固有の `paths` 等) の生成スクリプト
- 特定ツール固有の install hook
- 標準対応していない自社内 AI tool 向けの変換

「将来必要になるかも」だけで先行追加はしません (引き算原則 / YAGNI)。
