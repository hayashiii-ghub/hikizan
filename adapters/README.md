# adapters/

このディレクトリは Agent Skills 標準でカバーできない特殊ケース用の予約領域です。**現状は空**で問題ありません。

## なぜ空か

hikizan は (a) Claude Code plugin (`/plugin` 経由) と (b) skill pack (`npx skills add github:hayashiii-ghub/hikizan`) の 2 経路で配布します。両方とも標準仕様の範囲で動くため、ハーネス独自の変換 / 配置スクリプトは通常不要です。

Codex 連携を求める場合も hikizan 自身では adapter を持たず、OpenAI 公式の [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) を別途 install する設計です (詳細は root の README「Codex 併用」節)。

`adapters/` はこの「標準仕様の範囲外、かつ既存 plugin で代替できない」ニーズが将来出てきた場合の置き場所です。

## 何が入る予定か

実需要が出た場合のみ追加:

- 標準仕様外の独自 frontmatter 拡張 (例: ツール固有の `paths` 等) の生成スクリプト
- 特定ツール固有の install hook
- 標準対応していない自社内 AI tool 向けの変換

「将来必要になるかも」だけで先行追加はしません (引き算原則 / YAGNI)。
