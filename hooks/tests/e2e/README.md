# E2E overhead benchmark

「hikizan のハーネスが賢いモデルのボトルネックになっていないか」を実測する (Phase 4-1)。`hooks/tests/run.sh` の決定論テストとは別物で、**ユーザが手で回す**。実 `claude -p` セッションを spawn するため token を消費し、認証済み CLI が要る。CI には載せない。

## 実行

```bash
bash hooks/tests/e2e/bench.sh --dry   # claude を呼ばず配線だけ確認
bash hooks/tests/e2e/bench.sh         # フル実測 (課金あり)
```

## 計測内容

3 シナリオを plugin 有無 / tier 別に走らせ、`--output-format json` の `num_turns` と `usage.output_tokens` を比較する。

| シナリオ | plugin | tier |
| --- | --- | --- |
| small-baseline | off | — |
| small-plugin-standard | on | standard |
| submit-plugin-standard | on | standard |
| small-plugin-guided | on | guided |

## 受け入れ基準

- **standard-tier の小修正で output token overhead < +15%** (no-plugin baseline 比)。これが「強モデルに無税」の定量条件。
- hook 発火数 (`~/.hikizan/metrics.jsonl`) が run 間で一貫している。

## 結果の使い道 (Phase 4-2)

standard と guided の overhead 差を見て、Claude Code の **既定 tier** を確定する。

**決定 (2026-06-10)**: CC 既定 = `standard`。根拠は「CC には hooks の floors があり、出口契約 + floors が二重に効くため手順を自由化しても worst-case を防げる」。実装は `session-context.sh` の `HIKIZAN_TIER` 既定値 (= `standard`) と `context/standard-preamble.md` (opt-out 前文) に固定済み。E2E ベンチの定量確認 (overhead < +15%) は未実測のため、回したら本節に数値を追記する。`guided` にしたい環境は `HIKIZAN_TIER=guided` で opt-in。

> 注: 本ベンチは prompt を read-mostly に保ち (「実装しない」「push しない」)、bare run でも安全かつ安価にしている。実装まで走らせる重い計測をしたい場合は prompt を編集する。
