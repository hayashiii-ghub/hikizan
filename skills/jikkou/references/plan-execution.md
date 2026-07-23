# 計画実行モードの補足契約

計画実行の順序、停止条件、handoff、診断手順は`jikkou` SKILL.mdが正本。このfileはSKILL.mdへ転記しない入力shapeと分岐固有dataだけを定義する。

## 承認済みplanの入力shape

- change: [observable behavior]
- owner skill: `jikkou`
- file: [触るfile / directory]
- verification: [test / lint / type-check / 手動確認command]
- ADR: [任意。`sekkei`が決めたpath / decision / 理由]

軽量検討からはこのshapeの1 step、通常検討からは同shapeの複数stepを受ける。項目不足や未承認なら実装せず`sekkei`へ戻す。

## TDDへ渡すvertical slice

TDDの実行順とPRUNE witnessは`tdd.md`が正本。計画から次に閉じる1 sliceだけ、次のshapeへ落とす。

- entry: [user action / API call / public function]
- behavior: [観測したい振る舞い]
- observable output: [UI / response / return value / state change / persisted data]
- excluded layers: [このcycleで通さない層]

候補sliceは列挙してよいが、確定扱いは次の1件だけ。coverage gapは「受容 / 次slice / test level変更」のいずれかとして呼び出し元へ返す。

## ADR step

ADR作成・更新は、`sekkei`がplanへ記載しuserが承認したpath / decision / 理由だけを書く。CONTEXT.mdのdomain内容は`tansaku`が保守する。完成ADRへのlink-only変更は、planにCONTEXT pathとlink追加が明記され承認された場合だけ`jikkou`が行う。実装中に新しい判断やdomain事実を補わず、内容不足なら`sekkei`へ戻す。

## sadokuへ渡すevidence

handoffの`evidence`には、実装後の通常経路なら`BRANCH_SNAPSHOT + REVIEW_BASE=<merge-base>`、確定commitだけなら`COMMIT_RANGE=<base>...HEAD`、限定reviewなら`INDEX`または`WORKTREE`を含める。`BRANCH_SNAPSHOT`はcommit済み・staged・unstaged・untrackedの和集合として`sadoku`へ渡す。検証command、報告、diff、log本体はhandoff行の外に添える。
