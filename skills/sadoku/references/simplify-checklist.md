# simplify checklist (5 観点)

`sadoku` の simplify findings モードで参照する。各観点ごとの判定基準と書き直し方の指針。

simplify findings は **発見と提案まで**。実装は kouchiku に handoff block で委譲する (sadoku の役割境界)。

## 1. 重複

**判定基準** (いずれか):
- 同じ shape の logic / branch が 3 箇所以上に現れる
- parameter 違いだけで本質的に同じ flow
- copy-paste 痕 (近接位置の類似 block、変数名だけ差し替えた構造)

**書き直し方**:
- helper function に抽出 (副作用と return 値が明確な単位で)
- shared module に置くかは「他 module からも呼ぶか」で判断
- 配置先の判断 (どの module に置くか) は kouchiku が controller として行う

**severity 目安**: 重複が広域 (3+ file) なら high、同 file 内なら medium / low。

## 2. 命名

**判定基準** (いずれか):
- 同 module 内で `getX` / `fetchX` / `loadX` のような近義語が混在
- abbreviation の混在 (`usr` / `user`、`btn` / `button`)
- 既存 convention と外れる新規導入 (例: snake_case 中心の repo に camelCase 関数を追加)

**書き直し方**:
- 命名規約を `project-context.md` (3. 命名規則の踏襲) で確認、揃える
- 一括 rename の影響範囲確認は kouchiku に handoff

**severity 目安**: public API の命名揺れは high、internal helper の揺れは medium / low。

## 3. 不要な抽象化

**判定基準** (いずれか):
- 1 箇所からしか呼ばれない wrapper / helper
- premature な generic (`T` で受けて実際は 1 type でしか使わない)
- 過剰な interface (impl が 1 つに対して interface を切っている、DI の予定もない)
- 多段の delegation (A → B → C → 実処理、間が単純な passthrough)

**書き直し方**:
- inline 化、interface 解消
- 「将来増える予定がある」場合は据え置き判断、kouchiku に確認
- YAGNI 原則を引用根拠にできる場合は high severity

**severity 目安**: production code の見通しを大きく悪化させているなら high、軽微な over-engineering は medium / low。

## 4. dead code

**判定基準** (いずれか):
- 未使用 export (どこからも import されていない)
- 到達不能な branch (前段の条件で必ず false / true)
- comment-out された code block が永久放置されている
- 未使用 import / 未使用変数 / 未使用 type

**書き直し方**:
- 削除を提案。controller が確定したら一括 remove
- 「念のため残す」は不採用 (引き算原則、git history に残るので復元可能)
- comment-out 放置は理由コメントなしなら必ず削除

**severity 目安**: 公開 export の dead は high、private helper の dead は medium、変数 / import の dead は low。

## 5. efficiency

**判定基準** (いずれか):
- 明確な O(n²) → O(n) の改善余地 (linear で書ける箇所が nested loop になっている)
- 重複 allocate (毎 call で同じ object / array を生成、cache 化可能)
- 不要な intermediate collection (map → filter → reduce の中間配列が大きい)
- 同期処理で並列化が自明 (independent な await が serial)

**書き直し方**:
- 計測 / benchmark なしで自明な改善のみ取り上げる (premature optimization を避ける)
- 計測を要する判断は kouchiku に振る (= simplify findings の範囲外、kouchiku が「やる価値ある」で評価)

**severity 目安**: hot path や user-visible な performance に直結するなら high、それ以外は medium / low。

## findings を出さない場合

- `findings: 0` を明示する (空 section にしない)
- 「整理する価値が見当たらない」と判断した理由は完了記録に 1 行残す
- 「念のため指摘」を増やさない (= sadoku 停止条件「些細な指摘マシン化」防止)

## 他原則との関係

- **引き算原則** の operationalization (meta-principle を per-PR の判定基準に落とす)
- **shiken の PRUNE** と相補: PRUNE は test 専用、simplify findings は production code 専用
- **sadoku の純化** を守る: sadoku は実装しない、発見と提案のみ
- **評価=環境変化** と整合: handoff 後の実装結果 (整理後 diff + test pass) を verification log として残す
