# 専門家レビュー persona の起動条件

`sadoku` の通常レビューモードで使う 4 persona。**全対象に起動するのではなく、起動条件にヒットした persona のみ**。対象は diff でも指定範囲のコードでもよい。

## 目次

- [起動の流れ](#起動の流れ)
- [persona 一覧](#persona-一覧)
- [起動判定で迷ったとき](#起動判定で迷ったとき)

## 起動の流れ

1. controller (sadoku 本体) が対象 (diff / 範囲) を読む。あわせて近隣の類似実装を軸 3、関連する repo convention を軸 4、脅威モデル / 設計意図を軸 6 で抽出する (出どころ優先 ①CONTEXT.md ②PR / issue intent ③user に 1 行)
2. 各 persona の起動条件を照合
3. ヒットした persona だけ subagent として起動。**起動時に、手順 1 で抽出した比較対象、repo convention の出典、脅威モデル / 設計意図 (何を守り、何を受容しているか) を渡す**。subagent の採否判定はこの前提に照らす。渡さないと勝手な基準で問題を作り、懸念の羅列になる
4. subagent の出力を controller が**裏取り** (該当 file:line を実際に grep / Read で確認、subagent の主張を鵜呑みにしない)
5. 裏取り済の指摘を `references/synthesis.md` の手順で 1 本に統合して報告に反映

並列起動上限は 3。

## persona 一覧

### code-quality

**起動条件 (いずれか 1 つでも該当)**

- Standard / Deep の対象に production code が含まれる
- user が「既存コードに合うか」「書き方がおかしくないか」「もっとシンプルにできないか」と明示する (Quick でも起動)
- 新しい制御フロー / error handling / helper / wrapper / interface を導入している

**観点**

| カテゴリ | 確認 |
|---|---|
| codebase fit | 近隣の類似実装と比べて、制御フロー / API の使い方 / 命名が不必要に外れていないか |
| simplicity | 同じ振る舞いと制約を、より少ない分岐・層・概念で表せないか |
| readability | 処理の主経路と副作用が追えるか、間接参照が意図を隠していないか |
| duplication / dead code | 対象変更が重複や未使用要素を増やしていないか |

通常レビューでは対象変更とその理解に必要な近隣だけを見る。対象外の production code まで整理候補を探すのは simplify モードの責務。

prompt 詳細: `references/agents/reviewer-code-quality.md`

### security

**起動条件 (いずれか 1 つでも該当)**

- 認証 / 認可フロー (login / signup / role / permission / session) に対象が触れている
- 入力経路 (HTTP handler / form / file upload / URL parser / SQL builder / shell exec) の変更
- 暗号化 / hashing / secret 取扱 (env, key, token) の変更
- 外部 fetch / SSRF を生む可能性のある URL 動的構築
- output 系 (HTML render / log / error message) に user 由来データが入る

**観点**

| カテゴリ | 確認 |
|---|---|
| 認証 | timing attack / brute force / 既存 session の取扱 |
| 認可 | role 判定の漏れ / 横展開可能性 |
| 入力検証 | type guard / boundary / escape |
| Injection | SQL / shell / template / XSS |
| Secret | log への混入 / commit message / response body |
| SSRF | 内部 IP / metadata endpoint に到達可能か |

prompt 詳細: `references/agents/reviewer-security.md`

### architecture

**起動条件 (いずれか 1 つでも該当)**

- 新規 module / directory が追加されている
- 既存の依存方向に逆走する import が追加されている (例: domain → infra)
- public API シグネチャ (関数 / 型 / endpoint) の変更
- 抽象化レベルが既存と乖離した実装 (例: util に business logic、domain に IO)
- 5+ ファイル touch の重い変更

**観点**

| カテゴリ | 確認 |
|---|---|
| 結合度 | 単方向か / 循環していないか |
| 凝集度 | 同 module 内の責務が一貫しているか |
| 抽象化 | 適切な層に置かれているか |
| module 境界 | public / private の境界と配置が既存構造に合うか |
| 変更容易性 | 依存先の変更が不要な箇所へ波及しないか |

prompt 詳細: `references/agents/reviewer-architecture.md`

### adversarial

**起動条件 (いずれか 1 つでも該当)**

- 状態管理 (race condition, retry, idempotency) に対象が触れている
- 外部 API / 非同期処理 / queue / scheduler の変更
- error handling パス (try/catch, fallback, retry) の追加・削除
- ユーザに与える影響が大きい (課金 / 通知 / データ破壊系)

**観点**

- 6 ヶ月後に問題化しうるシナリオを 1 つ書く
- edge case の見落とし (null / 空配列 / 巨大入力 / 同時実行 / 部分失敗)
- 悪意ユーザの行動 (= security と重複しない範囲、主に整合性破壊)
- error path が silent fail にならないか

**注意**: adversarial persona は controller が**inline** で実行する (subagent には委譲しない、視覚判断を含むため)。

## 起動判定で迷ったとき

- 5+ ファイル touch なら **architecture** は必ず起動
- 入力経路に触れたら **security** は必ず起動
- Standard 以上の production code なら **code-quality** は必ず起動
- どれも該当しないが対象が大きい (diff 200 行超 / 範囲が 1 module 超) なら adversarial だけ inline で実行
