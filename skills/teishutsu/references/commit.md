# commit 契約

commit を作る前に読む共通契約。commit の粒度はユーザ承認の単位で決めず、作業を意味のある単位で保存する checkpoint として決める。commit の実行権限は、commit を行う skill の契約に従う。subject の形式は `naming.md`、長期的に残す実装判断は PR 本文の Workflow 節が正本。

## 粒度

1 commit には、独立して説明・検証・revert できる 1 つの変更を入れる。

- plan step / TDD slice / file と commit を 1 対 1 にしない
- 小さな PR は 1 commit でよい
- commit 作成自体を必須にしない
- 関連する検証が green の状態で commit する

## 同じ commit に入れるもの

- 振る舞いの変更と、その regression test
- source と、source から生成した artifact
- schema 変更と、green を保つために同時変更が必要な consumer / migration
- rename と、その rename で必ず壊れる参照更新

## 分けるもの

- 別 issue として独立して動く変更
- 単独で revert できる別の振る舞い
- 実装中に見つけた、要求外の cleanup

## commit 前の点検

1. staged diff を 1 文で説明する
2. staged file に要求外の変更が無いことを確認する
3. 関連する検証を実行し、green の出力を控える
4. `naming.md` に従って subject を付ける。diff だけでは理由が分からないときだけ body を書く
5. 重要な判断と根拠は commit message だけに置かず、PR 本文の Workflow 節にも残す
