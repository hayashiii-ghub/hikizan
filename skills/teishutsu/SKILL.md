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

PR 本文ドラフトから PR open までの提出手順を扱う。submission の未確認項目 (リモート状態 / submodule 順序 / cwd ミス / reviewer 未指定の本番 PR) を hook より前に検出する。`sadoku` は review、`teishutsu` は提出に必要な本文と手順を担当する。

<!-- hikizan:contract:start -->
## 共通契約

全 hikizan skill 共通。ここを変えたら `scripts/check-consistency.sh` が 5 skill の同一性を検査する。

- **tier**: 環境が宣言する自律度に従う。`hikizan-tier: standard` (floors=hooks のある環境: Claude Code の /plugin、floors 導入済み Cursor 等) は invariant を満たす限り「既定手順」を圧縮してよい。`guided` (既定 / floors 未導入) は「既定手順」を遵守する。未宣言なら `guided` 扱い。
- **risk dial**: 可逆で推測可能 → 自律で進める / 計画の分岐点 → 確認を取る / 不可逆・破壊的 → 止めてユーザ確認。tier に関わらず不可逆操作は止める。
- **必須 (invariant)**: 「必須」と記す項目は全 tier で省略不可 — 検証ログは command 出力を引用し自己申告にしない / PII・Secrets scan / 命名規約 / 破壊的操作の明示確認。
- **既定手順 (procedure)**: 「既定手順」と記す節は guided では遵守、standard では invariant を満たす限り圧縮・省略してよい。
- **handoff**: skill 間遷移は次の block を出す。
  ```
  handoff: [skill]
  reason: [なぜ今渡すか]
  context: [症状 / 仕様 / 設計判断]
  evidence:
    - [file:line / command output / logs]
  expected return:
    - [戻してほしい成果物]
  ```
- **命名**: PR / branch / step は issue 名 / 機能名 / branch 名で呼ぶ。独自連番 (PR-1 等) 不可、重複時のみ -v2, -v3。
<!-- hikizan:contract:end -->

## worktree 検出 (必須)

`git rev-parse --git-dir` と `--git-common-dir` を `pwd -P` で正規化して比較。異なれば worktree 内 — branch 名を完了記録の `worktree` 行に記録する。

## 起動 (router)

| 入力トリガー | 動作 |
| --- | --- |
| `PR文書いて` / `PR description` | Step 4 の PR 本文ドラフトだけを実行して終了 |
| `PR出す` / `PR提出` / `PR ready` / `提出して` | 提出フロー (6 step) を実行 |

`kouchiku` 計画実行の完了報告直後など状態からの起動は、誤起動回避のため 1 行確認 (`実装完了です。PR を出しますか?`) を挟む。

## 提出フロー (必須: 順序を守る)

不可逆・外向きの操作のため、6 step の順序と確認は全 tier で省略しない。

1. **リモート状態確認** — `git fetch --all` → `git log HEAD..origin/$BRANCH --oneline`。リモート先行があれば別実装の存在を警告し両案残すか確認。non-fast-forward は pre-push hook が最終 block するが、teishutsu が先に選択肢 (pull --rebase / 別 branch / abort) を提示。失敗時は次に進まない
2. **submodule 先行** — `git submodule status --recursive`。未 commit / 未 push があれば submodule 内で commit message ドラフト → user 承認 → commit + push を**親 commit より必ず先**に
3. **parent commit** — 親 repo で `git add` (submodule pointer 含む) → commit message ドラフト → PII / Secrets scan → user 承認 → commit。push はしない
4. **PR 本文ドラフト** — `references/pr-template.md` を読み 5 セクション本文を作る。必須 intake は (issue / 計画 / change intent のいずれか) + (diff または変更ファイル一覧) + (検証コマンドまたは手動確認)。足りなければ推測で埋めず欠落だけ確認。PII / Secrets scan を本文に実行。`PR文書いて` 経由はここで終了
5. **push** — `git push`。pre-push hook が non-ff / force-to-protected を block。block 時は Step 1 に戻る。失敗時は PR 作成に進まない
6. **PR 作成** — `gh pr create` 直前で必ず `pwd` と `git rev-parse --show-toplevel` を user に見せ対象 repo を明示確認 (submodule / 親 repo の取り違え防止)。`--repo <owner>/<repo>` で対象固定。default `--draft --reviewer @user` (pre-pr-create hook が両方無いと block)。Step 4 の本文を `--body "$(cat ...)"` で渡す

## Handoff Intake

`kouchiku` 計画実行の完了報告 or user から呼ばれる時の期待入力: `change intent / files changed / verification / scope notes / submodule status / PR body (任意) / target repo (任意) / reviewer (任意)`。足りなければ推測で補完せず停止条件として欠落を user に問い合わせる。

## 必須 (停止条件 invariant)

- **PR 本文 intake 不足** (Step 4 の必須 intake が欠けている)
- **PII / Secrets 混入** (本文 / commit message / release notes に email / token / 個人名等)
- **cwd 不整合** (cwd が submodule 側なのに親 repo の PR を作ろうとしている、or 逆)
- **未確認の force push** (`--force` / `--force-with-lease` が main / master / develop 対象。pre-push hook と二重)
- **reviewer 未指定 + 非 draft** (pre-pr-create hook と二重)
- **リモート衝突未解決** (Step 1 で先行 commit を検出したのに reconcile せず push)
- **submodule pointer 変更ありで submodule 未 push** (Step 2 を skip すると post-commit hook が warning)
- commit / PR 本文の生成は inline で出して user 承認を仰ぐ。承認なしで commit / push / PR 作成しない

## hook との二重構造

| 停止条件 | 本 skill | hook |
| --- | --- | --- |
| non-fast-forward | Step 1 で先制検出 | pre-push が deny |
| force to protected | Step 5 で警告 | pre-push が deny |
| reviewer / draft 未指定 | Step 6 で確認 | pre-pr-create が deny |
| submodule 未 push | Step 2 で順序遵守 | post-commit が warning |

skill は通常フローの手順、hook は skill を経由しない操作への補完検査。teishutsu は hook より前に確認項目を検出する。

## 完了記録 (必須)

機械検証可能項目は command 出力をそのまま引用する。

```
worktree / mode: PR body draft / submit
remote state:  fetched / in sync / had divergence / 検証ログ: [git log HEAD..origin/... 最終行 or "(empty)"]
submodule:     none / [path] commit [hash] pushed / 検証ログ: [git submodule status]
parent commit: [hash] - [message 1 行]
push result:   pushed to origin/[branch] / hook blocked: [reason] / 検証ログ: [push 最終行]
PR body:       drafted / provided / skipped / PII scan: clean / found
cwd at gh:     [pwd 出力] / 検証ログ: [pwd 実出力]
PR:            [url] / draft / reviewers: [@user]
```

## subagent

PR 本文ドラフトと git/gh 操作が中心、subagent gate に該当しない (inline 実行)。

## references/

- `pr-template.md` — PR 本文の contract (5 セクション template / 手順 / 文章チェック / PII scan / 粒度ルール)
