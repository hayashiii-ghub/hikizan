# instrument を 1 つだけ仕込むパターン

`jikkou` の診断分岐で「hypothesis を 1 つ confirm / discard する」ための instrument 集。**証拠は 1 つだけ**。1 回の実験で hypothesis の真偽を分ける。仕込んだら必ず外す (commit には残さない)。

## 7 パターン

### 1. console.log / print (最頻)

**用途**: 関数呼び出し時の引数 / 戻り値 / 分岐の経路を確認

```js
console.log('FOO', { input, intermediate });
return result;
```

**注意**: 出力過多になりやすい。**1 関数 1 ログ**を原則とし、関数名を tag (`FOO`, `BAR`) で区別する。

### 2. breakpoint / debugger

**用途**: 状態が複雑で、ステップ実行で stack frame を見たいとき

```js
debugger;  // または IDE 上で行クリック
```

**注意**: production code には残さない。`.skip` と同じく commit 前に grep で削除する。

### 3. git log -S "string"

**用途**: 「いつから出ているバグか」を時間軸で追う、過去 commit を含めて検索

```bash
git log -S "問題のシンボル名" --oneline
git log -S "問題の文字列" -p -- path/to/file
```

**注意**: 二分探索と組み合わせて、culprit commit を特定する。

### 4. strace / dtruss / opensnoop (システムコール)

**用途**: ファイル / network / process syscall レベルで何が起きているか

```bash
# このtaskが起動し、所有を確認したPIDだけを対象にする
# Linux
strace -e openat,connect -p <pid>
# macOS
sudo dtruss -t open -p <pid>
```

**注意**: 重いので絞り込み必須。「特定のfileを開いていないはず」「socket connectしていないはず」のような外形hypothesisのときだけ。このtaskが起動したPID以外へのattach、別userのprocess、`sudo`が必要な実行は、対象と取得範囲を示してuserの明示確認を得る。traceにbuffer内容を含めず、secretを保持するprocessへattachしない。

### 5. network panel / network log

**用途**: HTTP request / response の実物を確認、payload と header を見る

```
DevTools > Network > Preserve log
```

または、userが承認したendpointへ最小requestで再現:

```bash
curl --fail --silent --show-error --output /dev/null --write-out '%{http_code}\n' -X POST https://approved.example/... -H 'Content-Type: application/json' --data-binary @request.json
```

**注意**: Authorization / Cookieをverbose logへ出さない。外部URL、private IP、metadata endpoint、認証headerが必要なrequestは、送信先・送信data・保存する出力を示してuser確認を得る。responseを保存するときは既存redactorを通し、無ければsecretを含む可能性のあるheader/bodyを保存しない。

### 6. env diff (環境差異)

**用途**: 「俺の環境では動く」を覆すために、挙動へ関係する非機密env変数と依存versionを比較

```bash
diag_dir="$(mktemp -d)"
chmod 700 "$diag_dir"
trap 'rm -rf "$diag_dir"' EXIT
# hypothesisに必要な非機密keyだけallowlistする。値を保存する前にkeyごとの機密性を確認
for key in LANG LC_ALL NODE_ENV CI; do
  printf '%s=%s\n' "$key" "$(printenv "$key" 2>/dev/null || true)"
done | sort > "$diag_dir/env.allowlisted"
node --version > "$diag_dir/deps"
npm ls --depth=0 >> "$diag_dir/deps"
```

**注意**: env全量dumpは禁止。token / credential / endpointを含みうるkeyはallowlistへ足さない。追加keyが必要なら値を保存する前にredactし、mode 700のtask固有一時directoryだけへ保存する。

### 7. tee + grep (出力スナップショット)

**用途**: 1 回しか発生しない event の出力を後で grep するために保存

```bash
diag_dir="$(mktemp -d)"
chmod 700 "$diag_dir"
trap 'rm -rf "$diag_dir"' EXIT
# secretを出さないと確認したcommandだけ保存する。可能性があれば既存redactorをpipeの手前で適用
<safe-command> 2>&1 | tee "$diag_dir/snapshot.log"
grep -E 'ERROR|WARN' "$diag_dir/snapshot.log"
```

**注意**: 固定temp名を使わない。保存fileはtask終了時に削除し、重要な非機密evidenceだけを報告へ引用する。

## 共通ルール

- **1 hypothesis = 1 instrument**。同時に 2 つ仕込んだ時点で「とりあえず試そう」モード、停止条件発動
- 仕込んだ instrument は **fix 確定後すぐ revert** する (PR 出荷前に必ず grep で確認)
- production code に `console.log` / `debugger` / `dump()` 等が残ったら `sadoku` の停止条件で指摘される
