# fan-out (広域読みの subagent 委譲)

探索が広く、独立に読める領域に割れるとき、`tansaku` の深い読みを read-only な探索 subagent に分散する。合成 (用語確定 / CONTEXT.md / 報告 / handoff) は controller (tansaku 本体) が持つ。狙いは controller の context を file dump で埋めず、ダイジェストだけ受け取ること。

subagent は領域ごとの構造化データ (Map 断片 + evidence + 用語候補 + Unknowns) を返すだけ。確定と決定は subagent に持たせず、controller が一度だけやる。

## 起動条件

- 独立に読める領域 / sub-question が 3 つ以上に割れるときだけ fan out する。1 本の線形トレース (定義から呼び出し元へ辿るだけ) は inline のまま読む。
- 並列上限は 3。領域がそれ以上あるなら、controller が重要な 3 つを選び、残りは inline で読む。
- 利用中 harness が native subagent を提供するときだけ使う。対象範囲、read-only 制約、返却形式を self-contained prompt として渡し、runtime に read-only sandbox や tool 制限があれば併用する。特定 harness の agent 名や custom agent file を前提にしない。
- subagent が使えない場合は同じ対象を controller が inline で読む。並列度を下げても探索範囲と裏取り基準は狭めない。

## controller が渡すもの

- 1 subagent = 1 領域 / sub-question。対象範囲 (dir / file / シンボル) を明示する。
- 返してほしい形をそのまま指定する (下の「返すもの」)。

## subagent が返すもの (ダイジェスト)

- **Map 断片**：[path:line、役割]。
- **用語候補**：[語 = コード / docs 上の意味 (path:line)]。確定ではなく候補として返す。
- **Unknowns 断片**：コードと docs だけでは分からなかったこと。
- **返さないもの**：Terminology の確定 / CONTEXT.md への書き込み / 設計判断 / handoff の選択 / 実装コード。

## controller がやること (裏取りと統合)

1. **裏取り**：digest の file:line を鵜呑みにしない。曖昧なもの・報告の軸になるものは controller が自分で Read / grep で確認する。
2. **選別**：evidence の無い行は報告に載せず Unknowns へ回す (tansaku 本体のルールと同じ)。
3. **用語確定**：用語候補を突き合わせ、事実で決まるものだけ Terminology に確定する。事実で決まらない語だけ user に一問ずつ確認する。
4. **統合**：CONTEXT.md への diff 提案・報告・次の handoff は controller が一度だけ組む。

## やらないこと

- subagent に Terminology を確定させる / CONTEXT.md を書かせる / 設計判断や handoff を選ばせる (すべて controller 所有)。
- digest をそのまま報告に貼る (統合が controller の仕事)。
- 領域が割れていないのに fan out する (線形トレースは inline のほうが速い)。
