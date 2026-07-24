# PR draft

PR本文はreviewerが変更理由、実装、検証を判断できる最小構成にする。空sectionを`なし`で埋めない。

## Intake

- change intentまたはissue
- baseとの差分
- 実行した検証と結果

不足している事実を推測しない。diffとrepo内の情報で決まらない場合だけuserへ確認する。

## Title

repo規約を優先し、なければ`naming.md`に従う。変更後のobservableな結果を1行で表す。

## Body

基本は次の3項目で足りる。

```markdown
## Why

[解決する問題または変更理由]

## Changes

- [review可能な単位の変更]

## Verification

- `[command]` — [result]
```

移行、互換性、rollback、未解決risk、重要な設計判断がある場合だけ該当sectionを追加する。内部skillの順序や、実施していない工程のtraceは書かない。

## Scope

1 PRを1つのreview可能な目的にする。別々に価値を持ち単独revertできるcleanupは混ぜない。複数fileや複数commitでも同じ目的に必要なら分割しない。

## PII / Secrets scan

PR body、提出rangeの追加行とcommit message、release note、本文へ転載するlogをscanする。repo既存scannerは、対象repoがtrustedで、scanner本体・設定・依存を読め、networkやpluginを実行しない場合だけ使う。scanner関連fileが変更対象なら実行せず、built-in grepを使う。

temporary fileはmode 700のdirectory内に作り、permissionを600へ絞る。directory作成直後に冪等な`EXIT` cleanupを登録し、success・failure・interruptの全経路で削除する。既知のsecret値をlogへ出さない。

```bash
# email
grep -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' <draft>
# hikizan:token-pattern
grep -E '(sk-(proj-)?[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{16,}|xox[baprs]-[A-Za-z0-9-]{16,}|A(SI|KI)A[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|Authorization:[[:space:]]*(Basic|Bearer)[[:space:]]+[A-Za-z0-9._~+/-]{8,}|-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----)' <draft>
```

genericなcredential assignmentとチーム外の実名は目視する。matchがあれば公開前に除去し、0件ならscan対象と`clean (0 matches)`を報告する。
