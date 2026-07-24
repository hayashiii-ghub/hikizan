# test-first guidance

test-firstは、回帰価値が高く、既存harnessからobservable behaviorを安定して確認できる場合に使う。

優先する変更:

- bugfix：同じ入力で症状を再現できる
- business rule・validator・state transition：入出力契約が明確
- public API・data transform：consumerが依存する振る舞いがある

手順:

1. 守る振る舞いを入力と観測可能な出力で1文にする
2. 可能ならregression testを追加し、修正前に意図した理由で失敗することを確認する
3. 最小修正でtestを通す
4. 関連suiteを実行し、既存契約を壊していないか確認する
5. 重複testやprivate実装へ固定されたassertionだけ整理する

test harnessがない、再現が不安定、文言・style・単純な設定変更などでは無理にtest-firstへ寄せない。代わりに再現手順、static check、build、視覚確認など対象に合う証拠を残す。test有効性を証明するための追加儀式は行わない。
