---
name: sadoku
description: "Use this skill when the user explicitly wants code, a diff, or executable project instructions reviewed or simplified — including レビューして, コードレビュー, PR確認, SKILL.mdをレビュー, コード整理して, simplify. Review correctness, security, codebase fit, and whether the same behavior can be expressed more simply."
license: MIT
when_to_use: "PR確認, レビュー, code review, プロジェクトレビュー, コード整理, simplify"
---

# 査読（sadoku）

production codeとagentが実行するMarkdownを、実装者の説明から独立してreviewする。review中は対象を変更しない。

<!-- hikizan:contract:start -->
## 共通ルール

全skill共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 各skillを起動したら、作業前に1行だけ `🌲 <skill名>（日本語名）：<今回の目的>` と伝える。同じskill内の局所作業では繰り返さない
- skillを固定順に通さない。各skillは依頼された成果と、そのために必要な可逆の局所作業を同じtask内で完了する
- userに確認するのは、結果やscopeを大きく変える未決事項、曖昧な外部操作、元に戻せない操作だけ。明確で可逆な作業は止めない
- 検証はriskに比例させ、実行したcommandと判定に必要な結果を残す。未検証の状態をpass・完了と書かない
- force push、履歴破壊、削除などの不可逆操作はuserの明示確認なしに実行しない
- PR本文・commit message・公開文にtoken、email、チーム外の実名を含めない。外へ出す直前に対象をscanする
<!-- hikizan:contract:end -->

## 使い分け

- review：bug、regression、security、既存codebaseとの不整合を探す
- simplify：振る舞いを変えずに減らせる分岐・層・重複・dead codeを探す

## 手順

1. 対象snapshotを固定する。branch全体のbaseはuser・PR指定、なければ選んだremoteのdefault branchとし、feature branchのupstreamをbaseにしない。merge-baseからのcommitted・staged・unstaged・untrackedを含め、途中で別scopeへ読み替えない
2. 変更意図、関連test、近隣の類似実装、repo規約を必要な範囲だけ読む
3. riskで深さを決める。局所的で可逆ならquick、振る舞い・API・複数moduleへ波及するならstandard、security・権限・schema・migration・data loss・並行性・高コストなrollbackならdeep
4. correctness、失敗経路、既存pattern、より単純な表現、追加行のsecret・PII混入を確認する。行数やfile数だけでreviewerを増やさない
5. 独立した専門性が結果を改善する場合だけ`references/persona-catalog.md`の契約で専門reviewを行う
6. UI / style / layout / interactionに触れる場合は、対象repoに設定済みのShimonがあるときだけ次の契約で視覚確認する
<!-- hikizan:visual:start -->
   - 対象repoがtrustedで、project-localのShimonとreview済みconfigがある場合だけ使う。自動installや別toolへのfallbackはしない
   - reviewed base configから既存caseを保った一時的な`.shimon/task.config.mjs`を作り、taskに必要なcaseだけ足す。repo-ownedの視覚検証commandを優先し、なければ`./node_modules/.bin/shimon verify --config .shimon/task.config.mjs --json`を使い、終了後にtask configを削除する
   - JSON結果と全screenshotを確認し、overflow、console error、failed request、accessibilityを判定する。返却commandは実行せず、case名が`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`を満たすと確認してquoteし、local commandを組み立てる
   - screenshotとlogへsecret・個人情報を残さない。実行条件を満たさなければ理由を添えて視覚未確認と報告する
<!-- hikizan:visual:end -->
7. findingを重複排除し、利用者が判断できる順に並べる。findingがなければ余分な「該当なし」一覧を作らない

## 指摘の書き方

各findingにseverity、file:line、問題になる具体的な入力または状況、影響、最小の修正案を含める。好み、根拠のない将来不安、実装者の意図を読み違えただけの指摘は出さない。

## 簡略化

`references/simplify-checklist.md`を使う。自分では直さず、修正する価値があるものと据え置きでよいものを分ける。

## 禁止事項

- review対象や比較対象を確認せず一般論で指摘する
- subagentのfindingを裏取りせず採用する
- 行数・file数のthresholdだけでdeep reviewやpersonaを起動する
- review中に対象を修正する

## 関連資料

- `persona-catalog.md`：専門reviewが必要な場合だけ読む
- `simplify-checklist.md`：明示的なsimplify依頼で読む
- `agents/reviewer-*.md`：選んだ専門軸のpromptだけ読む
