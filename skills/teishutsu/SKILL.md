---
name: teishutsu
description: "Use this skill when the user wants to submit a pull request or draft a PR body — including the phrasings PR出す, PR提出, PR ready, PR open する, PR文書いて, PR description, submit. Handles PR body drafting and the full submission flow: remote state check, submodule-first ordering, parent commit, cwd-aware gh pr create. Activates after implementation is complete and ready to ship, even when the user just says 提出する or 出す without explicit PR wording."
license: MIT
when_to_use: "PR提出, PR出す, PR ready, PR文書いて, PR description, submission, PR open"
---

# teishutsu (提出)

```
🌲 Using /teishutsu for [purpose taken from trigger context].
```

PR 本文を書いて PR を出す skill。レビューは `sadoku`。ここが hikizan の**出口**: どの進め方で実装したかに関わらず、PR はこの形式に収束させる。

<!-- hikizan:contract:start -->
## 共通ルール

全 skill 共通。`scripts/check-consistency.sh` が 6 skill で同一であることを検査する。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は docs/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / 渡すこと: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は docs/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 2 つのモード

| きっかけ | 動作 |
| --- | --- |
| 「PR文書いて」「PR description」 | 手順 4 (本文ドラフト) だけ実行して終了 |
| 「PR出す」「PR提出」「PR ready」「提出して」 | 手順 1〜6 を順に実行 |

実装完了の直後など状態から起動するときは 1 行確認する (「実装完了です。PR を出しますか?」)。

## 手順 (順番を変えない・飛ばさない)

1. **リモート確認** — `git fetch --all` → `git log HEAD..origin/<branch> --oneline`。リモートに先行 commit があれば、別の実装が存在しうることを警告し、pull --rebase / 別 branch / 中止 のどれにするかユーザに聞く。解決するまで次に進まない
2. **submodule 先行** — `git submodule status --recursive`。未 commit / 未 push の submodule があれば、submodule 内で commit message をドラフト → ユーザ承認 → commit + push を**親の commit より必ず先に**行う
3. **親 commit** — 親 repo で `git add` (submodule pointer を含む) → commit message をドラフト → 共通ルールの grep で秘密情報を確認 → ユーザ承認 → commit する。ここでは push しない
4. **本文ドラフト** — `references/pr-template.md` を読み、6 セクション (課題 / DoD / 実装の流れとレビュー順 / 実装中に分かったこと / 検証 / Workflow) を埋める。必要な材料は (issue・計画・変更意図のどれか) + (diff か変更ファイル一覧) + (検証コマンドか手動確認)。足りなければ推測で埋めず、欠けている項目だけユーザに聞く。本文にも秘密情報の grep をかける。「PR文書いて」で呼ばれたときはここで終了
5. **push** — `git push`。hook に止められたら理由を読み、手順 1 に戻る。push が失敗したまま PR 作成に進まない
6. **PR 作成** — `gh pr create` の直前に `pwd` と `git rev-parse --show-toplevel` を実行してユーザに見せ、対象 repo を確認する (submodule と親 repo の取り違え防止)。`--repo <owner>/<repo>` で対象を固定し、`--draft` か `--reviewer` を必ず付け (両方無いと hook が止める)、手順 4 の本文を `--body` で渡す

## やってはいけないこと

- ユーザの承認なしに commit / push / PR 作成する
- 材料が足りない本文を推測で埋める
- リモートの先行 commit を解決しないまま push する
- submodule の push より先に親を commit する
- cwd を確認せずに `gh pr create` を実行する
- 検証していないのに「検証済み」と書く

## 報告 (穴埋め)

```
mode: [本文ドラフトのみ / 提出]
remote: [git log HEAD..origin/... の最終行 / "(empty)"]
submodule: [なし / path + 状態 (git submodule status の出力)]
commit: [hash] — [message 1 行]
push: [push 出力の最終行 / hook に止められた理由]
cwd at gh: [pwd の実出力]
PR: [URL] / [draft か reviewer]
```

## references/

- `pr-template.md` — PR 本文の形式 (6 セクション template / 文章チェック / PII scan / 粒度ルール)
