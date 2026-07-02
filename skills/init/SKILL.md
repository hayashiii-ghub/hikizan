---
name: init
description: "hikizan の routing / safety を現在の project の CLAUDE.md に永続追記する。通常は SessionStart の context 注入で足りるため不要。ファイルとして残したいときだけ手動で呼ぶ。"
license: MIT
disable-model-invocation: true
user-invocable: true
when_to_use: "hikizan の規約を CLAUDE.md に書き込みたいとき (手動 opt-in)"
---

# hikizan:init

hikizan の routing / safety を、利用先 project の `CLAUDE.md` に重複なく追記・更新する **ユーザ明示 opt-in** の skill。`disable-model-invocation: true` なので model からは自動起動しない。

通常運用では SessionStart hook (`session-context.sh`) が同じ内容を毎セッション context に注入するため、この skill は不要。CLAUDE.md にファイルとして残し、レビューや他ツールと共有したい場合だけ使う。

## やること

1. plugin の `templates/CLAUDE.md` (= 注入と同一の単一ソース) を読む。Claude Code では `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md`。
2. 利用先 project 直下の `CLAUDE.md` を確認する。
   - 無ければ template の内容で新規作成する。
   - marker 区間 (`<!-- hikizan:conventions:start -->` 〜 `<!-- hikizan:conventions:end -->`) があれば、その区間を template の現内容で置き換える (内容が同一なら「最新です」と報告して終了)。
   - marker が無く `## hikizan Conventions` 見出しがある (旧形式) 場合は、その節 (見出しから次の H2 見出しの直前まで、無ければ末尾まで) を marker 付きの template 内容で置き換える。
   - どちらも無ければ末尾に template の内容を追記する。
3. 書き込んだ内容を user に提示する。

## ルール

- 既存 `CLAUDE.md` の hikizan 以外の内容を書き換えない (追記のみ)。
- 書き換えてよいのは hikizan の marker 区間 (旧形式では `## hikizan Conventions` 節) だけ。それ以外の既存内容に触れない。
- 書き込み先 path を user に明示してから書く (破壊的でないが host repo を変更するため)。
- template を本 skill 本文に転記しない (単一ソースは `templates/CLAUDE.md`)。
