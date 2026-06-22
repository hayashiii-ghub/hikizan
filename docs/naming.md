# 命名規範

hikizan が作る識別子の正本。
対象は branch 名 / commit subject / PR タイトル / issue タイトル。
散文の書き方は `docs/writing-style.md` が定める。
ここは「名前」だけを定める。

由来は hikizan 自身の運用から抽出したもので、外部出典は無い。
原則 #10「認知負荷の削減」の具体化として、名前の揺れを減らす。

付けたら、最後の「点検」を当てる。
直すのは規範に外れた名前だけ。

## 背骨

すべての識別子は、その変更が解く機能か issue で呼ぶ。
実装手段や独自連番では呼ばない。

- 英小文字の kebab-case を既定にする (語をハイフンでつなぐ)。
- `PR-1` / `step3` のような独自の通し番号を新設しない。GitHub が振る `#番号` はそのまま使う。
- 一つの branch / PR / issue は一つの機能に対応させる。複数機能をまたいだら分ける。
- branch / commit / PR / issue は同じ機能を同じ語彙で指す。

## branch

形は `<機能名>` の kebab。
機能名は issue タイトルか、無ければ「何を変えるか」を 2〜4 語で表す。

```
writing-style-kaku
tansaku-mermaid-views
minimal-approach-ladder
```

- 種別 prefix (`feature/` `fix/` 等) は付けない。hikizan は機能名だけで足りる規模。
- 日付や作業者名を入れない。

## commit subject

1 行目は命令形か現在形で「何が変わるか」を 1 文。
文末に句点は付けない。

- 50〜72 字を目安に収める。超える説明は本文へ送る。
- 本文が要るときは、subject の後に空行を 1 つ置いてから書く。
- 末尾に `Co-Authored-By:` の footer を残す (共同作業の記録)。

```
add naming norm doc (0.5.1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

## PR タイトル

hikizan は squash merge なので、PR タイトルはそのまま main の commit subject になる。
だから commit subject と同じ規則で付ける。

- 連番 (`PR-1`) でなく機能名で呼ぶ。一意性は GitHub の `#番号` で足りる。
- 末尾の `(#NN)` は squash 時に GitHub が自動で付ける。手で書かない。

## issue タイトル

branch 名のもとになる機能名か課題を端的に書く。
branch / PR と同じ語彙で対応づける。

例：issue「naming 正本化」に対し branch `naming-norm`、PR タイトル「add naming norm doc」。

## 点検

- 名前に実装手段でなく目的 (機能 / issue) が出ているか。
- 独自の通し番号を作っていないか。
- branch / commit / PR / issue が同じ機能を同じ語彙で指しているか。
- kebab-case を外れた表記 (空白 / 大文字 / snake) になっていないか。
