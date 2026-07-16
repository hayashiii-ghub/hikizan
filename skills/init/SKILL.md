---
name: init
description: "hikizan の routing / safety を、ユーザが指定した project instruction Markdown に永続追記する。通常は harness の context 注入や rule で足りるため不要。ファイルとして残したいときだけ手動で呼ぶ。"
license: MIT
disable-model-invocation: true
user-invocable: true
when_to_use: "hikizan の規約を project instruction file に書き込みたいとき (手動 opt-in)"
---

# hikizan:init

hikizan の routing / safety を、利用先 project の instruction Markdown (`CLAUDE.md` / `AGENTS.md` など) に重複なく追記・更新する **ユーザ明示 opt-in** の skill。`disable-model-invocation: true` なので model からは自動起動しない。

Claude Code / Codex / Cursor の plugin 経路では context 注入や rule で同じ内容が届くため、この skill は通常不要。skill-pack 経路、または規約をファイルとして残してレビューや複数ツールで共有したい場合に使う。

## やること

1. 本 skill と一緒に配布される `references/routing.md` を読む。このファイルは repo の `context/routing.md` から生成された参照コピー。
2. ユーザが指定した **利用先 project** と **書き込み先 instruction Markdown** を確認する。未指定なら書き込まずに両方を聞く。
   - `pwd` と、Git repo なら `git rev-parse --show-toplevel` で現在地を確認する。
   - 利用先 repo root と書き込み先の正規化済み絶対 path をユーザに明示する。
   - 書き込み先が利用先 repo root 自身または配下であることを確認する。
   - 現在地・repo・書き込み先がユーザの指定と一致しない、または書き込み先が repo 外なら停止する。active harness からファイル名を推測しない。
3. 指定された instruction Markdown を確認する。
   - 無ければ template の内容で新規作成する。
   - marker 区間 (`<!-- hikizan:conventions:start -->` 〜 `<!-- hikizan:conventions:end -->`) があれば、その区間を template の現内容で置き換える (内容が同一なら「最新です」と報告して終了)。
   - marker が無く `## hikizan Conventions` 見出しがある (旧形式) 場合は、その節 (見出しから次の H2 見出しの直前まで、無ければ末尾まで) を marker 付きの template 内容で置き換える。
   - どちらも無ければ末尾に template の内容を追記する。
4. 書き込んだ path と内容を user に提示する。

## ルール

- 利用先 repo とその配下の書き込み先は必ずユーザに指定してもらう。cwd や harness を根拠に自動選択しない。
- 既存 instruction Markdown の hikizan 以外の内容を書き換えない。
- 書き換えてよいのは hikizan の marker 区間 (旧形式では `## hikizan Conventions` 節) だけ。それ以外の既存内容に触れない。
- 書き込み先 path を user に明示してから書く (破壊的でないが利用先 repo を変更するため)。
- template を本 skill 本文に転記しない。repo の単一ソースは `context/routing.md`、配布時の参照先は生成物 `references/routing.md`。
