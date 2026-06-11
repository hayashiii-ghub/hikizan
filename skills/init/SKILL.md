---
name: init
description: "hikizan の routing / safety を現在の project の CLAUDE.md に永続追記する。通常は SessionStart の context 注入で足りるため不要 — ファイルとして残したいときだけ手動で呼ぶ。"
license: MIT
disable-model-invocation: true
user-invocable: true
when_to_use: "hikizan の規約を CLAUDE.md に書き込みたいとき (手動 opt-in)"
---

# hikizan:init

hikizan の routing / safety を、利用先 project の `CLAUDE.md` に重複なく追記する **ユーザ明示 opt-in** の skill。`disable-model-invocation: true` なので model からは自動起動しない。

通常運用では SessionStart hook (`session-context.sh`) が同じ内容を毎セッション context に注入するため、この skill は不要。CLAUDE.md にファイルとして残し、レビューや他ツールと共有したい場合だけ使う。

## やること

1. plugin の `templates/CLAUDE.md` (= 注入と同一の単一ソース) を読む。Claude Code では `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md`。
2. 利用先 project 直下の `CLAUDE.md` を確認する。
   - 無ければ template の内容で新規作成する。
   - あり、かつ `## hikizan Conventions` が無ければ末尾に追記する。
   - あり、かつ既に `## hikizan Conventions` があれば何もしない (重複させない)。
3. 書き込んだ内容を user に提示する。

## ルール

- 既存 `CLAUDE.md` の hikizan 以外の内容を書き換えない (追記のみ)。
- marker `## hikizan Conventions` が既にあれば上書きしない。
- 書き込み先 path を user に明示してから書く (破壊的でないが host repo を変更するため)。
- template を本 skill 本文に転記しない (単一ソースは `templates/CLAUDE.md`)。
