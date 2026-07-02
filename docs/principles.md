# hikizan 設計原則

skill / hook / docs が従う原則。各 skill 本文から参照するときは番号でなく名前で書く。

1. **レール・opt-out・floors**：skill 本文は弱いモデル基準のレール (番号付き手順 + 穴埋めテンプレ)。standard tier (hooks=floors のある環境) には opt-out 前文 (`templates/standard-preamble.md`) を注入し「手順は自由、出口は固定」にする。hooks は tier に関わらず効く決定論的な下限。自律度はモデル検知でなく、環境構築時にどこまで仕組みを用意したかで決まる。
2. **弱いモデル基準で書く**：skill 本文は 1 行 1 命令 / 抽象語彙を使わない / 規則より穴埋めテンプレート / 選択肢の数を減らす。賢いモデルへの自由は opt-out 前文で与え、本文の手順には書き込まない。
3. **出口契約**：形は手順ではなく成果物で揃える。どの進め方でも PR は `teishutsu` の 6 セクション (Workflow trace 含む) に収束させ、過程の把握は PR を読めばできる状態にする。
4. **skill 構成**：1 skill に複数 mode、手順詳細は references に分離、決定論的な処理は `scripts/` / `hooks/` に置く。SKILL.md は「モード表 (複数モードの skill のみ) + 番号付き手順 + やってはいけないこと + 穴埋め報告」に絞る。
5. **Controller Owns Information**：情報取得だけが目的の subagent はデフォルトで使わない。
6. **inline 既定、subagent は明示 gate**：subagent は (a) 重い情報取得 / (b) specialist review / (c) 機械的な fan-out の 3 つに限る。
7. **起動と文脈の明示**：announce-at-start / worktree 検出を全 skill で行う。
8. **評価は「環境変化」で見る**：報告のうち機械的に検証できる項目は command 出力をそのまま引用し、自己申告は不可。これはどの tier でも省略しない。
9. **文章の可読性**：結論を先に出す / 1 段落 1 主張 / 読み手の語彙 / 儀礼的表現を削る。詳細は `docs/writing-style.md`。
10. **認知負荷の削減**：選択肢 + 推奨度 N/10 + 1 行根拠 / 構造変更は図・線形手順は箇条書き / 3 案以上出さない。
11. **Vertical TDD**：`jikkou` が次に閉じる 1 つの observable behavior を slice として切り、`shiken` はその output が壊れた時に落ちる test だけを残す。
12. **工数は token 規模で考える**：重さは人間の作業時間でなく token 消費 / context 占有 / API コスト。行数・ファイル数はその proxy。実行者は AI agent である前提。
13. **ファクトチェック**：知識カットオフより後の事実や不確実な情報は、検索・fetch・一次ソースで裏取りしてから断定する。
14. **単一ソース**：trigger / 規約 / 共通ルール block は 1 箇所を正本にし、転記は生成 (`scripts/gen-trigger-docs.sh`) と lint (`scripts/check-consistency.sh`) で同期を保証する。手動転記しない。
