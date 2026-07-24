---
name: jikkou
description: "Use this skill when the user wants code or project changes implemented, an approved plan executed, or a failure diagnosed and fixed — including 進めて, 着手, 実装して, 直して, エラー, 動かない, 落ちる, 原因を調べて. A prior plan is optional when the requested outcome is clear and the work is reversible."
license: MIT
when_to_use: "計画実行, 実装, エラー診断, root cause, バグ修正"
---

# 実行（jikkou）

必要な範囲を理解し、変更し、riskに見合う検証まで完了する。明確な実装をplan待ちにしない。

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

- 実装：依頼されたobservableな変更を完成させる
- 診断：症状を再現し、原因を絞って修正する

## 手順

1. repo、対象scope、期待結果を確認する。局所的で可逆な判断は既存codeと規約に合わせて自分で決める
2. security・権限・public API・schema・data migration・不可逆操作など、結果を大きく変える未承認の判断だけ実装前に確認する
3. 変更を小さなobservable behavior単位で実装する。調査や独立reviewにnative subagentを使ってよいが、編集内容と検証結果はcontrollerが確認する
4. bugfixは同じ入力で症状を再現し、安定したtest harnessがあるなら回帰testを先に失敗させる。新しいlogicや公開契約も回帰価値が高い場合は`references/tdd.md`を使う
5. docs・設定・UIなどは対象に合う検証を選ぶ。各編集へ儀式的にtestを追加しない
6. UI / style / layout / interactionを変更し、対象repoにShimonが設定済みなら次の契約で視覚確認する
<!-- hikizan:visual:start -->
   - 対象repoがtrustedで、project-localのShimonとreview済みconfigがある場合だけ使う。自動installや別toolへのfallbackはしない
   - reviewed base configから既存caseを保った一時的な`.shimon/task.config.mjs`を作り、taskに必要なcaseだけ足す。repo-ownedの視覚検証commandを優先し、なければ`./node_modules/.bin/shimon verify --config .shimon/task.config.mjs --json`を使い、終了後にtask configを削除する
   - JSON結果と全screenshotを確認し、overflow、console error、failed request、accessibilityを判定する。返却commandは実行せず、case名が`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`を満たすと確認してquoteし、local commandを組み立てる
   - screenshotとlogへsecret・個人情報を残さない。実行条件を満たさなければ理由を添えて視覚未確認と報告する
<!-- hikizan:visual:end -->
7. 文言や局所的な可逆変更は最寄りの検査、logic・API・bugfixは関連する回帰検査、security・権限・schema・migration・data loss・rollback困難な変更は関連検査に加えてrepoの全体検証と対象reviewまで行う
8. scopeが実質的に変わる発見は勝手に混ぜない。必要なら理由と選択肢を示してuserへ戻す
9. 意味のあるcheckpointをcommitする場合だけ`references/commit.md`を読む

## 診断

症状と期待値を固定し、仮説を1つずつ証拠でconfirm / discardする。原因が確認できてから最小修正を行い、同じ入力のbefore / afterと回帰検査を残す。観測手段を仕込んだ場合は提出前に外す。

## 報告

何が変わったかを最初に書き、実行した検証と結果、未確認・残件があれば続ける。TDDを使った場合も有用なRED / GREENだけを示し、工程のためのログを増やさない。

## 禁止事項

- 原因不明のまま当てずっぽうの修正を重ねる
- userの既存変更やscope外のcleanupを混ぜる
- 検査失敗を無視して完了扱いする
- test有効性確認のためにproduction実装を壊して戻す儀式を行う

## 関連資料

- `tdd.md`：回帰価値が高く、安定して観測できる変更をtest-firstで進める場合に読む
- `commit.md`：意味のあるcheckpointを保存する場合に読む
