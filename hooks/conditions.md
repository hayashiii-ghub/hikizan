# hikizan hooks: stop condition matrix

Claude Code plugin の hooks で監視する条件 / 挙動 / 決定の一覧。実体は同階層の `hooks.json` と `scripts/`、判定ロジックの単体テストは `tests/`。

## マトリクス

| event | matcher / if | 条件 | 決定 | reason 伝達 |
|---|---|---|---|---|
| SessionStart | matcher `startup` | セッション開始 (startup) | `context/routing.md` の routing / ルールと active tier を stdout に出力し context 注入。tier=standard なら `context/standard-preamble.md` (opt-out 前文) も注入。host repo は書き換えない | stdout (context) |
| PreToolUse | `Bash(git push*)` | local が push 先 remote から N コミット遅れている (non-fast-forward)。remote はコマンドの明示 remote → branch.<name>.remote → origin の順に解決 | `permissionDecision: "deny"` + 選択肢 (pull --rebase / 別 branch / abort) | JSON reason |
| PreToolUse | `Bash(git push*)` | force 相当 (`--force` / `--force-with-lease` / `-f` / `-fv` に加え `+refspec` / `:branch` (削除) / `--delete`・`-d` / `--mirror` / `--prune`) が main / master / develop を対象にする | `permissionDecision: "deny"` + 確認要求 | JSON reason |
| PreToolUse | `Bash(rm -*)` / `Bash(git reset*)` / `Bash(git clean*)` / `Bash(git checkout*)` | 不可逆操作 (`rm -rf` / `git reset --hard` / `git clean -f` / `git checkout` discard) | `permissionDecision: "ask"` (block でなく確認) | JSON reason |
| PreToolUse | `Bash(gh pr create*)` | `--draft` / `-d` も `--reviewer` / `-r` も無い (flag 判定は quote-aware tokenizer によるトークン一致。引用文字列内の `-d` 等では発火・解除しない) | `permissionDecision: "deny"` + 選択肢 | JSON reason |
| PostToolUse (Bash) | `Bash(git push*)` / `Bash(gh pr create*)` / `Bash(rm -*)` / `Bash(git reset*)` / `Bash(git clean*)` / `Bash(git checkout*)` | floor 対象クラスの実行を記録、介入なし・決定なし | なし (metrics のみ) | metrics.jsonl |

## 決定の出し方

- **PreToolUse は JSON 決定方式**。各 hook は stdout に
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny|ask|allow","permissionDecisionReason":"..."}}`
  を出して exit 0 する (公式推奨形、`scripts/lib/decision.sh` の `hz_decision`)。reason は Claude 本体 / ユーザに relay される。
  - `deny`: 操作を止め、reason を Claude に返す (non-ff / 保護 branch への force)。
  - `ask`: ユーザに確認ダイアログを出す (不可逆操作)。N 択の文言は reason に書く。
  - jq 不在は各 hook の entry で `scripts/lib/guard.sh` の `hz_require_jq` が stderr + exit 2 の fail-closed にする (PreToolUse 3 hook + Cursor adapter)。`hz_decision` / `hz_cursor_decision` 内の degrade は defense-in-depth として残るが、entry で先に止まるため通常到達しない。
- **hook は PreToolUse の deny/ask のみ**。
- **判定は local 情報優先**。`git fetch --quiet` は実行するが、失敗時はローカル状態で判定を継続する。
- **保護 branch は main / master / develop で固定**。プロジェクト拡張は将来 `.claude-plugin/config.json` 等で外部設定化できるが現時点では未対応。

## force 保護のターゲット解決 (C3 対策)

force push の対象 branch は `scripts/lib/push-parse.sh` の `hikizan_push_targets` が解決する。awk による旧実装が素通しさせていた以下を閉じている (`tests/test-push-parse.sh`, `tests/test-pre-push.sh`):

- `git push --force origin HEAD:main`：refspec 右辺 (`main`) を対象として解決
- `git push --force origin`：ref 省略時は current branch に fallback
- `git -C <dir> push --force origin HEAD:develop`：`-C <dir>` を解決し、その repo の branch を見る
- `command git push ...` / 複数 refspec / `refs/heads/main`
- `git push origin +HEAD:main` / `git push origin :main` (削除)：`--force` 系フラグが無くても、`+refspec` マーカーや空 src (`:branch`) の refspec は force 相当として同じ検査を受ける (`hikizan_push_is_forceful`)
- `git push --delete origin main` / `git push -d origin main` も同様に force 相当として扱う
- **glob を含む refspec** (例 `git push --force origin refs/heads/*:refs/heads/*`) は解決先が `*` 等のメタ文字を含むため、保護 branch にマッチしうると見なして保守的に **deny** する
- **`--mirror` / `--prune`** は push 対象の branch を個別に列挙できない (全 ref を force 更新・削除しうる) ため、対象を特定せず保守的に **deny** する
- ターゲット解決とコマンドのトークン化は `set -f` (noglob) 下で行い、cwd のファイル名に依存しない (決定論)

破壊的コマンドの分類規約:

- **判定は anchored**: rm 系は「コマンド先頭 (sudo / command / 環境変数 prefix は skip) が `rm`」、git 系は「git の subcommand が reset / clean / checkout」のときだけ評価する。引用文字列に `--force push` や `reset --hard` が現れるだけのコマンド (例: `git commit -m "see reset --hard docs"`) は発火しない
- **rm**: 再帰 (`-r`/`-R`/`--recursive`、`-rv` 等のクラスタ含む) **かつ** 強制 (`-f`/`--force`) の両方を持つ時だけ ask。`rm --force file` (再帰なし) や `rm -f file` 単体は対象外
- **checkout**: `--` トークンを含む形 (`git checkout [-tree-ish] -- <path>`) / `git checkout .` / `-f`・`--force` を ask。ブランチ切替や `--` なしの pathspec (`git checkout file.txt`) は対象外

## 既知の限界

決定論層の floor であり、prose の停止条件 (各 SKILL.md) と二重化する前提。以下は hook 単独ではカバーしない:

- **compound command**: `cd x && rm -rf y` のように先頭が対象コマンドでない複合コマンドは `if` matcher (prefix) に一致せず発火しない (anchored 判定も head ≠ 対象で skip する)。skill 本文の停止条件で補完する。pre-pr-create はトークン列上で `gh pr create` を探すため `cd x && gh pr create` も script 段では拾えるが、そもそも CC の `if` matcher (prefix) を通らなければ script に届かないため、この既知の限界自体は変わらない。flag の分類も最初のセグメントだけを見る (`git checkout -b x && git checkout -- .` の後続セグメントは分類されない。cd 経由の素通りと同じクラス)。
- **`if` prefix に外れる rm**: `sudo rm -rf` / `/bin/rm -rf` / GNU 形の trailing flag (`rm dir -rf`) は CC の `if: "Bash(rm -*)"` に一致せず、CC では script に届かない。Cursor adapter (if なし) では `sudo rm -rf` は head 判定で拾うが、`/bin/rm` は拾わない。
- **exotic な git 呼び出し**: 絶対パス `/usr/bin/git push` や alias 経由など、matcher の prefix に外れる形は素通りしうる (script 内は `hz_git_subcommand` による anchored 判定だが、`if` 段で発火しなければ script に届かない)。
- **non-fast-forward 検査の範囲**: 比較対象は「解決した remote の current branch」(`<remote>/<branch>`)。URL 直指定の push (`git push https://... main`) は remote-tracking ref が無いため検査対象外。refspec で current branch 以外に push する形 (`HEAD:other`) の non-ff は見ない (force 相当の検査は別途効く)。
- **destructive 分類**: `rm -rf` / `reset --hard` / `clean -f` / `checkout` discard の 4 系統に限定。`git restore` 等は対象外。

## メトリクス記録

書き込み先: `~/.hikizan/metrics.jsonl` (環境変数 `HIKIZAN_METRICS_DIR` で上書き可、append only)。
実装: `scripts/lib/metrics.sh` の `hikizan_metrics_log` 関数を各 hook が source して呼ぶ。silent on failure (jq 不在 / dir 書き込み不可 等で hook 本体は壊さない)。

### スキーマ (1 行 1 JSON event)

```json
{"ts":"2026-06-10T14:46:00Z","event":"hook_fired","hook":"pre-push","condition":"force_protected","decision":"block","session_id":"abc123"}
```

| field | 値 |
|---|---|
| `ts` | RFC3339 UTC タイムスタンプ |
| `event` | `hook_fired` / `command_executed` |
| `hook` | `pre-push` / `pre-pr-create` / `pre-destructive` / `post-command` / `session-context` |
| `condition` | `nff` / `force_protected` / `no_draft_no_reviewer` / `destructive` / `inject` / `noop` / `none` |
| `decision` | `allow` / `block` (= deny) / `ask` |
| `session_id` | CC session id (stdin JSON より取得)、無ければ空文字 |

`event: "command_executed"` は `post-command` (PostToolUse) が floor 対象クラスの実行そのものを記録したもの。`decision` はそのコマンドに対して floor が下したであろう判定 (実際の決定ではない。PostToolUse は tool 実行後に発火するため介入できない)。`decision: "block"` の `command_executed` は floor がすり抜けられた bypass の証拠であり、見つけたら原因を切り分けたうえで回帰テストを足す。

### 集計例

```bash
# 実 session に絞る (手動テストの合成 id を除外する前置きフィルタ。以下の各例にも同様に足せる)
jq -r 'select(.session_id | test("^[0-9a-f]{8}-"))' ~/.hikizan/metrics.jsonl | head

# 過去の block / ask 件数を hook 別に
jq -r 'select(.decision == "block" or .decision == "ask") | .hook' ~/.hikizan/metrics.jsonl | sort | uniq -c

# 不可逆操作の確認要求 (ask) 回数
jq -r 'select(.condition == "destructive")' ~/.hikizan/metrics.jsonl | wc -l

# ask の承認率の近似 (destructive: 発火した ask に対し実行まで至った数)
jq -r 'select(.condition=="destructive") | .event' ~/.hikizan/metrics.jsonl | sort | uniq -c

# bypass 疑い (floor が deny するはずのクラスが実行されている)
jq -c 'select(.event=="command_executed" and .decision=="block")' ~/.hikizan/metrics.jsonl
```

ローテーションは size ベース (既定 1MB、`HIKIZAN_METRICS_MAX_BYTES`、1 世代保持)。自動 dashboard は未実装 (利用実績が貯まってから別 issue)。

## SessionStart の補足

- SessionStart(startup) hook の **stdout を CC が context 注入**する仕組みを使う。host repo の `CLAUDE.md` は書き換えない (常に installed version と同期、汚染なし)。ファイルとして残したいユーザは `/hikizan:init`。
- 注入内容の単一ソースは `context/routing.md` + active tier (`HIKIZAN_TIER`、既定 `standard`)。tier=standard のときだけ `context/standard-preamble.md` (opt-out 前文: 手順は自由、出口と floors は固定) を続けて注入する。guided はレール (skill の番号付き手順) をそのまま使うため前文なし。
- `resume` / `clear` / `compact` では実行しない (matcher が `startup` のみ)。

## テスト

決定論層は `tests/` で回帰検査する (bats 不要、`bash tests/run.sh`)。

```bash
bash hooks/tests/run.sh            # 全テスト
bash hooks/tests/run.sh push-parse # 特定テストのみ
```

| test | 対象 |
|---|---|
| `test-push-parse.sh` | force 検出 / ターゲット解決 (C3 バイパス 3 形を pin) |
| `test-pre-push.sh` | pre-push 統合 (deny/allow 決定) |
| `test-destructive.sh` | 不可逆操作の分類 |
| `test-pre-destructive.sh` | pre-destructive 統合 (ask/allow) |
| `test-pr-create.sh` | `hz_is_pr_create` / `hz_prcreate_needs_review` の単体 (quote-aware) |
| `test-pre-pr-create.sh` | pre-pr-create 統合 (-d / -r / deny) |
| `test-cursor-floors.sh` | cursor floors 統合 (force push deny / 破壊的操作 ask / 非 draft PR deny を Cursor I/O 経由で検査) |
| `test-tokenize.sh` | quote-aware tokenizer (`hz_tokenize`) の単体 |
| `test-jq-absent.sh` | jq 不在時の fail-closed (PreToolUse 3 hook + Cursor adapter は exit 2、session-context は noop) / post-command.sh は noop |
| `test-post-command.sh` | post-command 統合 (floor 対象クラスの実行だけ記録、それ以外は 0 行) |
| `test-metrics.sh` | `lib/metrics.sh` の size rotation (閾値超で `.1` へ退避、閾値未満では無変更) |

## 関連

- `hooks.json`：実体の hook 設定 (matcher / if / script 紐付け)
- `scripts/session-context.sh`：SessionStart on `startup` (routing / tier を stdout で context 注入)
- `scripts/pre-push.sh`：PreToolUse on `git push*`
- `scripts/pre-destructive.sh`：PreToolUse on `rm` / `git reset` / `git clean` / `git checkout`
- `scripts/pre-pr-create.sh`：PreToolUse on `gh pr create*`
- `scripts/post-command.sh`：PostToolUse on 同 6 if prefix (floor 対象クラスの実行を記録、決定なし)
- `scripts/lib/push-parse.sh` / `destructive.sh` / `pr-create.sh` / `decision.sh` / `decision-cursor.sh` / `guard.sh` / `tokenize.sh` / `metrics.sh`：共有ロジック
- `context/routing.md`：追加される本文
- `teishutsu` skill：hook と二重構造の通常フロー側
