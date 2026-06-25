---
name: sadoku
description: "Use this skill when the user wants code reviewed or findings simplified — including the phrasings レビューして, コードレビュー, 整理して, simplify. Activate after implementation, when reviewing a git diff before opening a PR, or when restructuring messy findings — even when the user doesn't say 'review' explicitly. レビュー系の語 (レビューして / コードレビュー) は通常レビュー、整理系の語 (整理して / simplify) のみ simplify findings を起動する。"
license: MIT
when_to_use: "PR確認, レビュー, code review, 整理, simplify"
---

# sadoku (査読)

```
🌲 Using /sadoku for [purpose taken from trigger context].
```

diff を見る skill。見つけた問題を直すのは `kouchiku`、テスト先行の実装は `shiken`、提出は `teishutsu` に渡す。

<!-- hikizan:contract:start -->
## 共通ルール

全 skill 共通。`scripts/check-consistency.sh` が 6 skill で同一であることを検査する。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は docs/naming.md)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は docs/writing-style.md の規範に従う
<!-- hikizan:contract:end -->

## 2 つのモード

| モード | きっかけ |
| --- | --- |
| 通常レビュー | 「レビューして」「コードレビュー」 |
| simplify | 「整理して」「simplify」「スリム化したい」(明示されたときだけ。「コードレビュー」では起動しない) |

diff があるだけでは始めない。状態から起動するときは 1 行確認する (「diff を検出しました。レビューしますか?」)。

## 手順 (通常レビュー)

1. `references/project-context.md` の観点で対象 repo の前提 (依存関係 / テスト構造 / 命名規則) を確認する
2. diff の行数で深さを決める: 50 行以内かテスト変更のみ → Quick / 50〜500 行 → Standard / 500 行超か security に触れる → Deep
3. 実装者の説明・PR 本文・前段の報告は鵜呑みにしない。finding の根拠は強い順に採る: ①テストの pass/fail ②diff ③周辺コード ④検証ログ ⑤実装者のメモ
4. 下の「停止条件」を上から順に diff に当てる。該当したら作業を止めてユーザに確認する
5. Standard 以上で security / architecture に触れる diff なら、subagent (`agents/reviewer-security.md` / `agents/reviewer-architecture.md`、他ハーネスでは `references/agents/` の同一コピー) を起動する (最大 3 並列、条件は `references/persona-catalog.md`)。返ってきた finding は自分で diff を読み直す / テストを再実行して裏取りしてから採用する
6. 「merge 後に壊れる一番現実的なシナリオ」を 1 つ書く。Quick では省略してよいが、bugfix / 挙動変更 / business rule / API / security の diff では Quick でも書く
7. UI / style / レイアウトに触れる diff なら、視覚エビデンスを取る (web project かつ `sitesnap` があるとき。shot で撮って Read で読み戻し、check で overflow / console / a11y の合否を見る)。撮れない環境は「視覚未確認」と明記する
8. 下の「報告」を埋めて返す

## 停止条件 (上から順にチェックし、該当したら止める)

- email / token / 実名が diff・commit message に混入している (grep recipe は `skills/teishutsu/references/pr-template.md` の「PII / Secrets scan」)
- `console.log` / `debugger` / 一時的な debug 出力が production コードに残っている
- 理由の書かれていない `.skip` / `xfail` がある
- mock の存在や呼び出し回数を assert している / テストのためだけの method が production class にある
- bugfix なのに root cause 1 文と同じ入力での before/after が無い
- diff が複数の issue にまたがっている (1 issue = 1 PR)
- 「最新の X」「Y が標準」のような外部事実が URL なしで根拠になっている
- 仕様・データ形状・権限・時系列の前提が崩れると壊れる変更なのに、diff / テスト / 周辺コードでその前提を確認できない (命名の好みや将来の漠然とした不安では止めない)
- 識別子が grep でヒットしない / lockfile 変更の理由が分からない → 推測で補完せず質問する

## 手順 (simplify)

1. 重複 / 命名 / 不要な抽象化 / dead code / 効率 の 5 観点で production code を見る (判定基準は `references/simplify-checklist.md`)
2. finding ごとに severity (high / medium / low) と扱い (本 PR で修正 / メモに記録 / 別 issue 候補 / 据え置き) を付ける
3. **自分では直さない**。high だけ `kouchiku` に渡す。medium / low はユーザ判断に委ねる
4. 0 件なら `findings: 0` と書く

## やってはいけないこと

- 見つけた問題を自分で直す (`kouchiku` へ)
- 「たぶん大丈夫」で停止条件を流す
- subagent の finding を裏取りせずに採用する
- 出力なしで「scan した」「テスト通った」と書く

## 報告 (穴埋め)

最初に結論を 1 文。続けて確認項目を箇条書きにする。検証はコマンド出力の最終行をそのまま貼る。

[1 文: レビュー結論。そのまま出せるか、止めるべきか]

- files / depth: [N ファイル (+X / -Y)、Quick / Standard / Deep]
- stop conditions: [該当 N 件 → 各 1 行 / なし]
- PII: [grep コマンド + 出力。0 件なら "0 matches"]
- failure scenario: [merge 後に壊れる現実的なシナリオ 1 つ / 該当なし]
- visual: [sitesnap shot のパス / 視覚未確認 (理由) / 該当なし]
- verification: [コマンド] → [出力の最終行をそのまま]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `project-context.md`：diff 読解前の文脈確認の観点
- `persona-catalog.md`：専門家レビュー (security / architecture / adversarial) の起動条件
- `simplify-checklist.md`：simplify の 5 観点判定基準
- `agents/reviewer-security.md` / `agents/reviewer-architecture.md`：他ハーネス向けコピー (plugin `agents/` と同一内容)
