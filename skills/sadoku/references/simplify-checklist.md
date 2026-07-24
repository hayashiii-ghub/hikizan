# simplify checklist

振る舞いを変えずに、理解・変更・検証する対象を減らせるかを見る。

- 重複：同じ判断や変換が複数箇所にあり、1つへ寄せると責務が明確になるか
- 分岐：到達不能、常に同じ結果、前段で保証済みのguardが残っていないか
- 抽象化：consumerが1つしかないwrapper、将来用interface、意味を増やさないlayerがないか
- 状態：導出できる値を別stateとして持ち、同期処理を増やしていないか
- dead code：未参照symbol、古いfallback、comment-out、使われないconfigがないか
- 命名：近隣patternと違う語が、実際の責務を隠していないか

短くなるだけで境界が曖昧になる変更は勧めない。security、data loss、accessibility、明示的なcompatibility処理は行数削減より優先する。

findingには削減できる概念・分岐・fileと、振る舞いを保てる根拠を示す。好みだけのrenameや将来不安は出さない。
