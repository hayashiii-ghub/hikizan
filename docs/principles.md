# hikizan 設計原則

skill / hook / docs が従う 12 原則。各 skill 本文から参照するときは番号でなく名前で書く。

1. **3 層構造**: invariant (全 tier 必須の保証) / 既定手順 (guided 向け、standard は圧縮可) / floors (hooks の決定論的下限) を分ける。自律度は「環境が宣言する tier × 操作の不可逆度」で決まり、モデル検知には依存しない。
2. **skill 構成**: 1 skill に複数 mode、手順詳細は references に分離、決定論的な処理は `scripts/` / `hooks/` に置く。SKILL.md は mode router + invariant + 出力契約に絞る。
3. **Controller Owns Information**: 情報取得だけが目的の subagent はデフォルトで使わない。
4. **inline 既定、subagent は明示 gate**: subagent は (a) 重い情報取得 / (b) specialist review / (c) 機械的な fan-out の 3 つに限る。
5. **起動と文脈の明示**: announce-at-start / worktree の Step 0 検出 / invariant 冒頭ガード。
6. **評価は「環境変化」で見る**: 完了記録のうち機械的に検証できる項目は command 出力をそのまま引用し、自己申告は不可。これは全 tier で省略できない invariant。
7. **文章の可読性**: 結論を先に出す / 1 段落 1 主張 / 読み手の語彙 / 儀礼的表現を削る。
8. **認知負荷の削減**: 選択肢 + 推奨度 N/10 + 1 行根拠 / 構造変更は図・線形手順は箇条書き / 3 案以上出さない。
9. **Vertical TDD**: `kouchiku` が次に閉じる 1 つの observable behavior を slice として切り、`shiken` はその output が壊れた時に落ちる test だけを残す。
10. **工数は token 規模で考える**: 重さは人間の作業時間でなく token 消費 / context 占有 / API コスト。行数・ファイル数はその proxy。実行者は AI agent である前提。
11. **ファクトチェック**: 知識カットオフより後の事実や不確実な情報は、検索・fetch・一次ソースで裏取りしてから断定する。
12. **単一ソース**: trigger / 規約 / 契約 block は 1 箇所を正本にし、転記は生成 (`scripts/gen-trigger-docs.sh`) と lint (`scripts/check-consistency.sh`) で同期を保証する。手動転記しない。
