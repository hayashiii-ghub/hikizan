# Phase 5: Cursor floors — 評価と移植

## 背景

リファクタ計画では Phase 5 を「Cursor 側には hooks (floors) が無いため guided tier 既定で守る」と仮置きし、Cursor hooks API を調査してから着手判断するとしていた。Phase 4 後に調査した結果、**前提が覆った**。

## 調査結果 (2026-06)

Cursor は agent 向けの lifecycle hooks を提供しており、`beforeShellExecution` で shell コマンドを実行前に block / 確認できる。

- 設定: `~/.cursor/hooks.json` (user) または `<project>/.cursor/hooks.json` (project)、`version: 1`。
- 入力 (stdin JSON): top-level `command` / `cwd` / `conversation_id` / `hook_event_name` / `workspace_roots`。
- 出力: `{"permission":"allow"|"deny"|"ask","user_message":...,"agent_message":...}`。exit code 2 も block (= deny) 扱い。
- 他にも `beforeReadFile` / `preToolUse` / `beforeMCPExecution` 等がある。

Claude Code の `PreToolUse` + `permissionDecision` とほぼ同型。出典: Cursor 公式 docs (cursor.com/docs/agent/hooks)。

## 評価モード判定

```
Verdict: Pivot
Reasons:
  1. [user 制約] 本 plugin の核心目的は composer 2.5 等の低自律モデルを「制御」すること。
     composer は Cursor 上で動く。Cursor に floors が無いという前提だったため guided
     prose 頼みだったが、決定論的 floors を置けるなら制御目的に直結する。
  2. [feasibility] beforeShellExecution は CC の PreToolUse とほぼ同型 (permission
     allow/deny/ask, 入力に command/cwd)。force 保護・破壊的検出の pure logic
     (push-parse.sh / destructive.sh) はハーネス非依存で、I/O glue だけ足せば再利用できる。
  3. [cost] 追加コストは薄い adapter 1 本と decision emitter 1 本のみ。pure logic は
     既に 57+ assertion で検査済み。glue も 7 assertion で検査した。
If pivot: 「Cursor には floors を置けない、guided で守る」→「CC と同じ floors を Cursor に
          移植する。tier は floors の有無ではなく既定手順の拘束度として残す」へ方針転換。
```

## 移植したもの

| 成果物 | 内容 |
| --- | --- |
| `cursor/scripts/before-shell.sh` | `beforeShellExecution` adapter。破壊的操作 → ask、保護 branch への force push → deny |
| `hooks/scripts/lib/decision-cursor.sh` | Cursor permission JSON emitter (CC の `decision.sh` の Cursor 版、pure logic は共通) |
| `cursor/hooks.json` | adapter を登録する hooks.json テンプレ |
| `hooks/tests/test-cursor-floors.sh` | Cursor 形式 input → permission output の glue テスト (7 assertion) |

pure logic (`push-parse.sh` / `destructive.sh`) は CC hooks と**同一ファイルを再利用**しており、二重実装ではない。

## install (Cursor)

1. hikizan repo を clone (skill pack の `npx skills add` は skills/ しか配置しないため、floors は別途配置する)。
2. `~/.cursor/hooks.json` (または project の `.cursor/hooks.json`) で `before-shell.sh` の**絶対パス**を指す:

   ```json
   {
     "version": 1,
     "hooks": {
       "beforeShellExecution": [
         { "command": "/abs/path/to/hikizan/cursor/scripts/before-shell.sh" }
       ]
     }
   }
   ```

   `cursor/hooks.json` は相対パスのテンプレ。実環境では絶対パスにする。
3. `jq` が要る (CC hooks と同じ)。

## 現状の限界 / 未検証

- **実 Cursor 環境では未検証**。glue は本 repo の test runner で検査済みだが、実際の Cursor が想定通り stdin JSON を渡し permission を解釈するかはライブ確認が必要。relying する前に Cursor 上で 1 度 deny / ask を目視すること。
- non-fast-forward 検査は移植していない (CC の pre-push のみ)。Cursor adapter は不可逆性の高い force / destructive に絞った。
- compound command (`cd x && rm -rf y`) と exotic な git 呼び出しの限界は CC hooks と同じ (`hooks/conditions.md`「既知の限界」参照)。
- Cursor 配布で floors を自動配置する仕組みは無い (手動 hooks.json)。skill pack と floors を 1 コマンドで入れる導線は今後の課題。

## tier への含意

floors が Cursor にも置けるようになったため、tier は「floors の有無」ではなく「既定手順の拘束度」を表す軸として一貫する。floors を入れた Cursor 環境は `HIKIZAN_TIER=standard` を宣言してよい (CC と同じ理屈)。floors 未導入なら `guided` 既定のまま。
