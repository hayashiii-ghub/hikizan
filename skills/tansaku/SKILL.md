---
name: tansaku
description: "Use this skill when the user wants investigation itself as the deliverable: codebase mapping, impact analysis, related-file discovery, or terminology clarification — including 探索して, 全体像を掴んで, 影響範囲を調べて, 関連ファイルを洗って, 用語を整理して. Do not activate merely because a normal implementation needs local reading."
license: MIT
when_to_use: "探索, 全体像把握, 影響範囲調査, 用語整理"
---

# 探索（tansaku）

調査結果を証拠付きで返す。設計や実装を求められていない限り、対象を変更しない。

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

## 手順

1. 調べる問いと対象範囲を1文で固定する。対象が一意なら確認のために止まらない
2. README、project instructions、関連するcode・testから、問いに答える最小範囲を読む
3. 定義、参照、呼び出し元、データの流れを辿る。履歴やTODOは、現在のcodeだけでは理由を判断できない場合に限って見る
4. 独立した重い調査軸が複数あり、native subagentが使える場合だけread-onlyで分担する。契約は`references/fanout.md`を読む
5. repo特有のdomain用語や一般的な意味と異なる語があれば、初出に平易な意味、code上の役割、file:lineを1〜2文で添える。一般的な技術用語の用語集は作らない
6. 観測した事実、そこから直接導ける影響、まだ分からないことを分ける。推測で空欄を埋めない
7. domain用語や不変条件の永続化は、userが文書化を求めた場合か、同じ誤解が繰り返される根拠がある場合だけ提案する。通常の探索では新しいCONTEXT.mdを持ち込まない

## 報告

結論を先に置き、主要なpath・symbol・testへfile:lineを添える。repo特有の用語は必要なものだけ短く説明し、影響範囲と未確認事項があれば続ける。図が文章より明確な依存関係だけ、小さなmermaidを1枚使う。

## 禁止事項

- 調査依頼を設計会議やdocumentation作業へ自動的に広げる
- evidenceのない推測を確定事項として扱う
- subagentへ用語確定、設計判断、file変更を任せる

## 関連資料

- `fanout.md`：広い調査をnative subagentへ分ける場合だけ読む
