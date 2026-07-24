# minimal approach

要求を満たす最小案を選ぶため、次の順に確認する。

1. その変更は本当に必要か
2. platform標準または既存の依存・patternで解けるか
3. 新しい層・設定・文書を増やさず局所変更で解けるか
4. 要求外のcleanupや将来拡張を別scopeへ出せるか

削ってはいけないもの:

- trust boundaryの検証
- data lossと失敗時cleanupへの対処
- securityとprivacy
- accessibility
- 問題を再現するために必要な検証

planには、採用案、主な変更、検証、意図的に見送るscopeだけを残す。行数見積りや点数評価のためにplanを膨らませない。
