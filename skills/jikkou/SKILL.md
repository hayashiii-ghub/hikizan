---
name: jikkou
description: "Use this skill when the user wants to execute an already-approved plan or diagnose a failure — including phrasings 進めて, 計画実行, 着手, 実装開始, 実装して, エラー, 動かない, 落ちる, クラッシュ, 前は動いてた, 原因が分からない. Activate when the user just approved a plan and wants it built, or reports a bug/test failure whose root cause is unknown. 設計判断そのものは sekkei に戻す。"
license: MIT
when_to_use: "計画実行, 実装, エラー診断, root cause, バグ修正"
---

# jikkou (実行)

```
🌲 Using /jikkou for [purpose taken from trigger context].
```

承認済みの計画を実行し、原因不明の不具合を診断する skill。設計・計画・評価は `sekkei`、レビューは `sadoku`、提出は `teishutsu`、調べ直しは `tansaku` に渡す。方針の再決定が要るときは `sekkei` に差し戻す。

<!-- hikizan:contract:start -->
## 共通ルール

core skill (init を除く全 skill) 共通。正本は `scripts/contract.md` で、`scripts/gen-contract.sh` が各 SKILL.md のこの区間に書き込む (手で編集しない)。

- 元に戻せない操作 (削除 / force push / reset --hard / git clean) は、実行する前にユーザに確認する
- 「pass した」「確認した」と書くときは、コマンド出力の最終行をそのまま貼る。出力なしで完了と書かない
- 秘密情報 (token / email / チーム外の実名) を PR 本文・commit message に書かない。出す前に grep で確認する
- commit する場合は `jikkou` の commit 契約に従う。独立して説明・検証・revert できる 1 つの変更を、関連検証が通った状態で保存する
- PR / branch / step は機能名か issue 名で呼ぶ。PR-1 のような独自の連番を作らない (詳細は `teishutsu` の naming reference)
- 別の skill に渡すときは 1 行で書く: `handoff: [skill] / brief: [1 文] / evidence: [file:line かコマンド出力]`
- 日本語の文章は `shippitsu` の writing-style 規範に従う
<!-- hikizan:contract:end -->

## 3 つのモード

| モード | きっかけ | 出すもの |
| --- | --- | --- |
| 計画実行 | 「進めて」「計画実行」「着手」(計画の承認後) | 動くコード + 検証ログ |
| 診断 | 「エラー」「動かない」/ 原因の分からない不具合・test failure | root cause 1 文 + fix |
| TDD 実装 | 純ロジック / ビジネスルール / API / バグ修正で回帰が高くつく箇所 (「TDD」「テスト先行」「テストから書く」) | RED→GREEN→PRUNE ログ + 実装 |

計画がまだ承認されていない、または方針を決め直す必要があるときは `sekkei` に渡す (自分で設計判断をしない)。

## 手順 (計画実行)

1. 承認済みの計画を再読する。不明点があれば実装前に聞く。計画が無い / 未承認なら `sekkei` に戻す
2. step を 1 つずつ自分で実装する (subagent に投げない)
3. 純ロジック / ビジネスルール / API / バグ修正の step は TDD 実装モードで書く: 1 slice ずつ RED→GREEN→PRUNE (下記「手順 (TDD 実装)」)
4. 各 step の後に検証コマンドを実行し、出力の最終行を控える。失敗したら次の step に進まず診断に入る。意味的 checkpoint を保存する場合は `references/commit.md` に従い、現在の repo / branch / 承認済み scope を確認してから commit する
5. UI / レイアウト / 視覚に触れる step は、検証コマンドに加えて次の順で視覚検証も通す
<!-- hikizan:visual:start -->
   - repo-owned command / configの内容を読み、対象repoが信頼済みと確認できる場合だけ実行する。外部PR、出所不明、または`ui:verify` / `shimon.config.mjs`自体が未reviewの変更なら自動実行せず、user確認または隔離環境を要求する
   - `ui:verify` scriptがあればそれを優先し、なければ`shimon.config.mjs`とinstall済みの`shimon`があるときに`shimon verify --json`を実行する。自動installや別toolへのfallbackはしない
   - どちらの入口でもJSONのpassを判定に使い、返された全screenshotを読み戻して目視する。overflow / console error / failed request / a11yを確認する
   - 失敗caseは、case名が`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`を満たし、reproduce commandがcanonical shimon形式 (`shimon verify --case <name> --json`) と一致すると確認できた場合だけ再検証する。不明なcommand文字列は実行しない
   - probe / screenshotに認証情報・個人情報・tokenを残さない。認証済み画面を扱う場合は`screenshot.mask`を確認する
   - 信頼を確認できない、未設定、実行不能、または必要なJSON evidenceを得られない場合は「視覚未確認」と理由を報告する
<!-- hikizan:visual:end -->
6. 計画に無いファイルに 5 つ以上触れそうになったら、または方針の再決定が要ると分かったら、止めて `sekkei` に差し戻す
7. scope 外の発見は実装せず「実装中に分かったこと」にメモする
8. 全 step 完了後、下の「報告」を埋めて `sadoku` に渡す。handoff の `brief` は実装した observable behavior + この実装固有の判断 / 受容リスク (あれば) とし、`evidence` は完成 diff と検証を特定できる file:line / command に絞る。報告・diff・検証ログ本体は handoff 行の外に添え、`sadoku` の共通観点は再掲しない

詳細: `references/plan-execution.md`

## 手順 (診断)

1. 実装の変更を止める
2. 症状をそのまま書き出す: error message / stack trace / 再現手順 / 期待値と実際の値
3. 原因の仮説を 1 文で書く: 「root cause は [X]。根拠は [evidence]」
4. `references/diagnosis-techniques.md` から確認手段を 1 つ選んで仮説を検証する
5. 当たっていたら直す。外れていたら 3 に戻る
6. 3 回外れたら、試した仮説 / 現状の見立て / 残る不明点を書いてユーザに判断を求める。方針ごと考え直す重い分岐なら `sekkei` に戻す
7. 直した後、同じ入力での before / after の出力をそのまま貼る。regression guard が要るなら TDD 実装モードで書く

## 手順 (TDD 実装)

純ロジック / ビジネスルール / API / バグ修正で回帰が高くつく箇所は、テスト先行で 1 振る舞いずつ閉じる。テストが先。fail を見るまで実装を書かない。

1. slice を 1 文で書く: 「[入力 / 操作] のとき [観測できる出力] になる」。1 文にできなければ実装に入らない
2. **RED**: その slice が失敗するテストを 1 つ書き、test runner を実行して fail の最終行を控える
3. **GREEN**: pass させる最小の実装を書き、pass の最終行を控える
4. **REFACTOR**: 重複除去と命名改善。テストは green のまま保つ
5. **PRUNE**: slice の振る舞い基準で残すテストを選び、不要を消す (判定は `references/testing-anti-patterns.md`)。原則 1 slice = 残すテスト 1 つ
6. **PRUNE 検証**: witness前にtracked worktree diff・index diff・status・untracked file hashを含むrepo fingerprintを保存する。observable outputを一時的に壊す → failを見る → 安全な一時backupから戻す → passを見る → fingerprintが完全一致したことを確認する。実装中の正当なdiffまでcleanにする要求ではない
7. 2 つ目の slice を勝手に始めない。gap は報告に書いて呼び出し元 (計画実行) に返す

必須 / skip してよい層と anti-pattern の詳細は `references/tdd.md`。

## やってはいけないこと

- 未承認 / 不在の計画をそのまま実装に移す (設計判断は `sekkei` に戻す)
- 原因不明のまま当てずっぽうの修正を重ねる
- scope 外の発見をついでに実装する
- 検証コマンドが失敗したまま次の step に進む
- fail を見る前に実装コードを書く (TDD 実装)
- RED / GREEN の実行を subagent に投げる (自分の目で出力を見る)
- planで承認されていないADRを作成・更新する (`sekkei`のADR候補を承認済みstepとして実行する場合だけ書く)

## 報告 (穴埋め)

最初に結論を 1 文。続けて内訳を箇条書きにする。検証はコマンド出力の最終行をそのまま貼る。

[1 文: どこまで進めた / 原因は何か]

- mode: [計画実行 / 診断 / TDD 実装]
- done: [N / M step] (計画実行のみ)
- verification: [コマンド] → [出力の最終行をそのまま]
- visual: [検証入口 (`ui:verify` / `shimon`) + screenshot のパスと pass / 視覚未確認 (理由) / 該当なし] (UI step のみ)
- root cause: [1 文 + before/after] (診断のみ)
- scope: [計画どおり / 外れたもの → sekkei へ差し戻し or 別 issue へ]
- RED/GREEN/PRUNE: [TDD 実装のみ] RED 最終行 / GREEN 最終行 / N 残し M 削除 + witness
- next: [sadoku / teishutsu / sekkei / なし]

worktree 内 (`git rev-parse --git-dir` と `--git-common-dir` の正規化結果が異なる) なら `worktree: [branch]` を 1 行足す。

## references/

- `commit.md`：commit の意味 / 粒度 / commit 前の点検
- `plan-execution.md`：計画実行の詳細 (TDD 分岐 / slice の渡し方 / 診断の入り方)
- `diagnosis-techniques.md`：診断の確認手段
- `tdd.md`：テスト先行が必須の層 / skip 可の層、PRUNE の詳細と anti-pattern の入口
- `testing-anti-patterns.md`：PRUNE の判定 5 問と anti-pattern 集
