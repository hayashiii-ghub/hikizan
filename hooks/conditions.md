# hikizan hooks: stop condition matrix

Claude Code plugin の hooks で監視する条件 / 挙動 / 決定の一覧。実体は同階層の `hooks.json` と `scripts/`、判定ロジックの単体テストは `tests/`。

## マトリクス

| event | matcher / if | 条件 | 決定 | reason 伝達 |
|---|---|---|---|---|
| SessionStart | matcher `startup` | セッション開始 (startup) | `templates/CLAUDE.md` の routing / ルールと active tier を stdout に出力し context 注入。tier=standard なら `templates/standard-preamble.md` (opt-out 前文) も注入。host repo は書き換えない | stdout (context) |
| PreToolUse | `Bash(git push*)` | local が remote から N コミット遅れている (non-fast-forward) | `permissionDecision: "deny"` + 選択肢 (pull --rebase / 別 branch / abort) | JSON reason |
| PreToolUse | `Bash(git push*)` | force 相当 (`--force` / `--force-with-lease` / `-f` / `-fv` に加え `+refspec` / `:branch` (削除) / `--delete`・`-d` / `--mirror` / `--prune`) が main / master / develop を対象にする | `permissionDecision: "deny"` + 確認要求 | JSON reason |
| PreToolUse | `Bash(rm -*)` / `Bash(git reset*)` / `Bash(git clean*)` / `Bash(git checkout*)` | 不可逆操作 (`rm -rf` / `git reset --hard` / `git clean -f` / `git checkout` discard) | `permissionDecision: "ask"` (block でなく確認) | JSON reason |
| PreToolUse | `Bash(gh pr create*)` | `--draft` / `-d` も `--reviewer` / `-r` も無い | `permissionDecision: "deny"` + 選択肢 | JSON reason |
| PostToolUse | `Bash(git commit*)` | submodule pointer 変更ありで submodule 側が未 push | warning を出力 (block しない) | stderr (warn) |

## 決定の出し方

- **PreToolUse は JSON 決定方式**。各 hook は stdout に
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny|ask|allow","permissionDecisionReason":"..."}}`
  を出して exit 0 する (公式推奨形、`scripts/lib/decision.sh` の `hz_decision`)。reason は Claude 本体 / ユーザに relay される。
  - `deny`: 操作を止め、reason を Claude に返す (non-ff / 保護 branch への force)。
  - `ask`: ユーザに確認ダイアログを出す (不可逆操作)。N 択の文言は reason に書く。
  - jq 不在環境では `hz_decision` が legacy の stderr + exit 2 に degrade する (フェイルセーフ)。
- **block 対象は PreToolUse のみ**。PostToolUse は副作用が完了済みのため warning に留める。
- **判定は local 情報優先**。`git fetch --quiet` は実行するが、失敗時はローカル状態で判定を継続する。
- **保護 branch は main / master / develop で固定**。プロジェクト拡張は将来 `.claude-plugin/config.json` 等で外部設定化できるが現時点では未対応。

## force 保護のターゲット解決 (C3 対策)

force push の対象 branch は `scripts/lib/push-parse.sh` の `hikizan_push_targets` が解決する。awk による旧実装が素通しさせていた以下を閉じている (`tests/test-push-parse.sh`, `tests/test-pre-push.sh`):

- `git push --force origin HEAD:main` — refspec 右辺 (`main`) を対象として解決
- `git push --force origin` — ref 省略時は current branch に fallback
- `git -C <dir> push --force origin HEAD:develop` — `-C <dir>` を解決し、その repo の branch を見る
- `command git push ...` / 複数 refspec / `refs/heads/main`
- `git push origin +HEAD:main` / `git push origin :main` (削除) — `--force` 系フラグが無くても、`+refspec` マーカーや空 src (`:branch`) の refspec は force 相当として同じ検査を受ける (`hikizan_push_is_forceful`)
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

- **compound command**: `cd x && rm -rf y` のように先頭が対象コマンドでない複合コマンドは `if` matcher (prefix) に一致せず発火しない (anchored 判定も head ≠ 対象で skip する)。skill 本文の停止条件で補完する。
- **`if` prefix に外れる rm**: `sudo rm -rf` / `/bin/rm -rf` / GNU 形の trailing flag (`rm dir -rf`) は CC の `if: "Bash(rm -*)"` に一致せず、CC では script に届かない。Cursor adapter (if なし) では `sudo rm -rf` は head 判定で拾うが、`/bin/rm` は拾わない。
- **exotic な git 呼び出し**: 絶対パス `/usr/bin/git push` や alias 経由など、matcher の prefix に外れる形は素通りしうる (script 内は `hz_git_subcommand` による anchored 判定だが、`if` 段で発火しなければ script に届かない)。
- **non-fast-forward の `-C` 解決**: force 保護は `-C <dir>` を解決するが、non-ff 検査の upstream 比較は cwd repo 基準が主。
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
| `event` | `hook_fired` |
| `hook` | `pre-push` / `pre-pr-create` / `pre-destructive` / `post-commit` / `session-context` |
| `condition` | `nff` / `force_protected` / `no_draft_no_reviewer` / `destructive` / `submodule_unpushed` / `inject` / `noop` / `none` |
| `decision` | `allow` / `block` (= deny) / `ask` / `warn` |
| `session_id` | CC session id (stdin JSON より取得)、無ければ空文字 |

### 集計例

```bash
# 過去の block / ask 件数を hook 別に
jq -r 'select(.decision == "block" or .decision == "ask") | .hook' ~/.hikizan/metrics.jsonl | sort | uniq -c

# 不可逆操作の確認要求 (ask) 回数
jq -r 'select(.condition == "destructive")' ~/.hikizan/metrics.jsonl | wc -l
```

ローテーション / 自動 dashboard は未実装 (利用実績が貯まってから別 issue)。

## SessionStart の補足

- SessionStart(startup) hook の **stdout を CC が context 注入**する仕組みを使う。host repo の `CLAUDE.md` は書き換えない (常に installed version と同期、汚染なし)。ファイルとして残したいユーザは `/hikizan:init`。
- 注入内容の単一ソースは `templates/CLAUDE.md` + active tier (`HIKIZAN_TIER`、既定 `standard`)。tier=standard のときだけ `templates/standard-preamble.md` (opt-out 前文: 手順は自由、出口と floors は固定) を続けて注入する。guided はレール (skill の番号付き手順) をそのまま使うため前文なし。
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
| `test-pre-pr-create.sh` | pre-pr-create 統合 (-d / -r / deny) |
| `test-cursor-floors.sh` | cursor floors 統合 (force push deny / 破壊的操作 ask を Cursor I/O 経由で検査) |

## 関連

- `hooks.json` — 実体の hook 設定 (matcher / if / script 紐付け)
- `scripts/session-context.sh` — SessionStart on `startup` (routing / tier を stdout で context 注入)
- `scripts/pre-push.sh` — PreToolUse on `git push*`
- `scripts/pre-destructive.sh` — PreToolUse on `rm` / `git reset` / `git clean` / `git checkout`
- `scripts/pre-pr-create.sh` — PreToolUse on `gh pr create*`
- `scripts/post-commit.sh` — PostToolUse on `git commit*`
- `scripts/lib/push-parse.sh` / `destructive.sh` / `decision.sh` / `metrics.sh` — 共有ロジック
- `templates/CLAUDE.md` — 追加される本文
- `teishutsu` skill — hook と二重構造の通常フロー側
