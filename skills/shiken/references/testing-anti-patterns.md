# testing anti-patterns

PRUNE フェーズで検出すべきパターン。いずれかに該当する test は書き直し or 削除。

## 1. mock の存在 / 呼び出し回数を assert

```ts
// 不可
expect(mockClient.send).toHaveBeenCalledTimes(1);
expect(mockLogger.error).toHaveBeenCalled();
```

呼ばれた回数は実装詳細であり仕様ではない。`send` を 1 回呼ぼうが 2 回呼ぼうが、最終的な状態 / 出力 / side effect が仕様通りなら test は pass であるべき。実装変更で test が壊れるなら、それは仕様変更ではなく実装詳細のリーク。

**書き直し方**: 観測可能な結果 (DB 状態 / API response / UI 表示 / log line の内容) を assert。

## 2. production class への test-only method

```ts
// 不可
class OrderService {
  // テストからだけ呼ばれる
  __resetForTesting() { ... }
  __getInternalQueue() { ... }
}
```

production code に test 専用 API が含まれている = 結合度が高すぎる。

**書き直し方**: 依存性を constructor / factory で注入、test 側で fake を渡す。

## 3. 部分 mock で structural assumption が隠れる

実 API の一部 field だけ mock した結果、本物の field が増えたときに test が壊れない。

```ts
// 危険
const mockUser = { id: 1, name: 'a' };  // 実体は { id, name, role, status, ... }
```

**書き直し方**: factory / builder で「実体に近い」test data を作る。または contract test を別途用意。

## 4. snapshot test の濫用

small diff で snapshot が大量更新される = snapshot は仕様を表現していない。

**判断基準**:
- snapshot 更新時に diff の意味を 1 文で言えなければ濫用
- 「render 結果全体」より「key behavior 1 つ」を assert する test に分解

## 5. `.skip` / `xfail` 理由なし放置

```ts
// 不可
it.skip('handles concurrent updates', () => { ... });
```

**ルール**:
- skip / xfail は理由コメント必須 (`// flaky — see #123`)
- 理由なしは Hard Stop (PR review 段階で sadoku が捕捉)

## 6. 同 assertion の別 setup での重複

3 つの test が違う setup で同じ最終 assertion を書いている = 1 つに統合できる可能性大。

**判断基準**: 「この test が落ちたとき、他の test も同時に落ちるか?」 → Yes なら統合。
