# 読み取り専用の分担

独立した調査軸が複数あり、並列化でcontextと時間を実際に節約できる場合だけ使う。

- 利用中harnessのnative subagentへ、問い、対象範囲、read-only制約、返却形式をself-contained promptで渡す
- harness固有のagent名やcustom agent fileを前提にしない。native subagentがなければcontrollerが必要範囲をinlineで読む
- 各subagentは担当領域の事実、file:line、関連test、未確認事項だけを返す
- controllerが重要なfileと主張を読み直し、重複を除いて1つの調査結果へ統合する
- 用語確定、設計判断、file変更は委譲しない
