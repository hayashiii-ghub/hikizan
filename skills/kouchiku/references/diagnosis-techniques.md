# instrument を 1 つだけ仕込むパターン

`kouchiku` の診断分岐で「hypothesis を 1 つ confirm / discard する」ための instrument 集。**証拠は 1 つだけ**。1 回の実験で hypothesis の真偽を分ける。仕込んだら必ず外す (commit には残さない)。

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
# Linux
strace -e openat,connect,read,write -p <pid>
# macOS
sudo dtruss -t open -p <pid>
```

**注意**: 重いので絞り込み必須。「特定の file を開いていないはず」「socket connect していないはず」のような外形 hypothesis のときだけ。

### 5. network panel / network log

**用途**: HTTP request / response の実物を確認、payload と header を見る

```
DevTools > Network > Preserve log
```

または curl で再現:

```bash
curl -v -X POST https://... -H '...' -d '...'
```

**注意**: cookie / token を log に残さない (PII 配慮)。

### 6. env diff (環境差異)

**用途**: 「俺の環境では動く」を覆すために、env 変数・依存 version を全列挙して比較

```bash
env | sort > local.env
# 他環境で同様に取得 → diff
node --version && npm ls --depth=0 > local.deps
```

**注意**: secret は redact してから diff する。

### 7. tee + grep (出力スナップショット)

**用途**: 1 回しか発生しない event の出力を後で grep するために保存

```bash
<command> 2>&1 | tee /tmp/snapshot.log
grep -E 'ERROR|WARN' /tmp/snapshot.log
```

**注意**: `/tmp` は再起動で消えるので、重要なら別保存。

## 共通ルール

- **1 hypothesis = 1 instrument**。同時に 2 つ仕込んだ時点で「とりあえず試そう」モード、停止条件発動
- 仕込んだ instrument は **fix 確定後すぐ revert** する (PR 出荷前に必ず grep で確認)
- production code に `console.log` / `debugger` / `dump()` 等が残ったら `sadoku` の停止条件で指摘される
