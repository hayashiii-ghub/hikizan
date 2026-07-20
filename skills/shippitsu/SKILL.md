---
name: shippitsu
description: "Use this skill when the user wants to write or revise Japanese prose — technical docs, articles, READMEs, explanations — including the phrasings 書いて, 文章書いて, 執筆, 推敲, リライト, 文章直して, 平坦な文章, 緩急をつけて, 読ませる文章にして. Activate when drafting or rewriting Japanese text against a writing norm; add cognitive rhythm for chapters, articles, and long-form explanations meant to be read sequentially. Code review goes to sadoku instead."
license: MIT
when_to_use: "執筆, 推敲, リライト, 文章を書く, 平坦な文章, 緩急, 読ませる文章"
---

# shippitsu (執筆)

```
🌲 Using /shippitsu for [purpose taken from trigger context].
```

日本語の文章を書く / 推敲する skill。標準規範は `references/writing-style.md` に従う。記事、書籍の章、読み物として順に読ませる長い解説、平坦さや緩急を直す文章では `references/cognitive-rhythm.md` を追加で使う。コードのレビューは `sadoku`、PR 本文は `teishutsu`、リポジトリ外の人間に配る PDF は `pdfmint` に渡す (markdown が既定、PDF 化は配布先次第)。

<!-- hikizan:contract:start -->
## 共通ルール

core skill (init を除く全 skill) 共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `jikkou` の commit 契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は `teishutsu` の naming reference)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は `shippitsu` の writing-style 規範に従う
<!-- hikizan:contract:end -->

## 2 つのモード

| モード | きっかけ |
| --- | --- |
| 新規 | 「文章書いて」「執筆」「README 書いて」/ 新規に日本語の文を書く |
| 推敲 | 「推敲」「リライト」「文章直して」/ 既存の文を規範に沿って直す |

## 適用プロファイル

| プロファイル | 対象 | 読む規範 |
| --- | --- | --- |
| 標準 | PR 本文 / 作業報告 / 通常の README / 短い説明 | `references/writing-style.md` |
| 読み物 | 技術記事 / 書籍の章 / 順に読ませる長い解説 / 平坦さや緩急を直す文章 | `references/writing-style.md` → `references/cognitive-rhythm.md` |

形式だけで読み物プロファイルにしない。読者に順に読み進めてもらう目的があるか、平坦さや緩急を直す指示があるときに選ぶ。

## 手順 (新規)

1. 何を・誰に・どの形式 (PR 本文 / docs / 記事 / README) で書くかを 1 文で確認する
2. 対象と指示から適用プロファイルを選ぶ
3. 標準では結論を先に置き、1 文目で「何が言いたいか」が分かる構成にする。読み物では、状況に根ざした問いや違和感から始めてよいが、第一段落で対象と論点を特定する
4. `references/writing-style.md` を読んで従う。読み物では、その後に `references/cognitive-rhythm.md` を読み、追加で従う。段落は一トピック、一文一行にする
5. 書き上げたら、読んだ規範の点検項目を上から当て、外れた箇所だけ直す
6. 下の「報告」を埋めて返す

## 手順 (推敲)

1. 対象の文と、直す狙い (規範違反の除去 / 短縮 / 読みやすさ / 平坦さや緩急) を確認する
2. 対象と指示から適用プロファイルを選ぶ
3. `references/writing-style.md` の各節を上から当てる。読み物では、その後に `references/cognitive-rhythm.md` の話題テスト、緊張台帳、拍の点検も当てる
4. 直すのは規範に外れた箇所だけ。意味を変える書き換えは元の主張を保つ
5. before / after を示せる粒度で直す。原文の事実・主張・語り手の判断状態を勝手に追加・削除しない
6. 下の「報告」を埋めて返す

## やってはいけないこと

- references の規範を SKILL.md 内に書き写す (詳細は各 reference が正本)
- 推敲で原文の主張・事実を勝手に足す / 消す
- 読み物プロファイルを標準の PR 本文・作業報告・通常の README・短い説明に適用する
- 緩急を作るために、原稿や資料にない出来事・判断状態・感情を作る
- 「自然にした」のような抽象指示だけで終える
- 単語狩りで品質を判定する (規範の節ごとに点検する)
- コードレビューを始める (`sadoku` へ)

## 報告 (穴埋め)

最初に結論を 1 文。続けて内訳を箇条書きにする。

[1 文: 何をどう書いた / 直したか、いまどういう状態か]

- mode: [新規 / 推敲]
- target: [何を・どの形式で]
- norm check: [当てた節 → 直した箇所 / 違反なし]
- next: [teishutsu / sadoku / pdfmint で PDF 化 / 完了]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `writing-style.md`：日本語文章規範の正本 (整形 / 段落と論証 / 厳密さ / 負荷管理 / 視点 / 演出 / LLM 句 / 冗長 / 誠実さ / 見出し)
- `cognitive-rhythm.md`：読み物向けの追加規範 (認知モード / 文の拍 / 密度波形 / 緊張 / 話題テスト)
