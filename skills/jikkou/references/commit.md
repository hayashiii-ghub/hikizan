# コミットの区切り

commitは必須工程ではなく、意味のある状態を保存するときだけ作る。

1 commitには、独立して説明・検証・revertできる1つの変更を入れる。振る舞いと回帰test、sourceと生成物、schemaと必須consumerなど、片方だけではgreenにならない変更は一緒にする。

コミット前：

1. repo rootとcurrent branchが対象と一致するか確認する
2. staged diffを1文で説明でき、scope外のfileがないか確認する
3. 変更riskに合う検証がgreenか確認する
4. repo規約を優先して簡潔なsubjectを付ける。diffだけでは理由が分からない場合だけbodyを書く
5. token、email、チーム外の実名やattribution trailerを含めない

別目的のcleanup、単独でrevertできる別挙動、無関係な生成物は分ける。
