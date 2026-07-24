## 共通ルール

全skill共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 各skillを起動したら、作業前に1行だけ `🌲 <skill名>（日本語名）：<今回の目的>` と伝える。同じskill内の局所作業では繰り返さない
- skillを固定順に通さない。各skillは依頼された成果と、そのために必要な可逆の局所作業を同じtask内で完了する
- userに確認するのは、結果やscopeを大きく変える未決事項、曖昧な外部操作、元に戻せない操作だけ。明確で可逆な作業は止めない
- 検証はriskに比例させ、実行したcommandと判定に必要な結果を残す。未検証の状態をpass・完了と書かない
- force push、履歴破壊、削除などの不可逆操作はuserの明示確認なしに実行しない
- PR本文・commit message・公開文にtoken、email、チーム外の実名を含めない。外へ出す直前に対象をscanする
