# プロジェクト文書の形式

hikizan が配る repo の README と AGENTS.md の正本。
スケルトンは `templates/README.md` と `templates/AGENTS.md`。

## 原則

README は人間の貢献者向け、AGENTS.md は agent 向け。
意図的に分け、重複させない。
境界は「人間の貢献者に要るか / agent の作業に要るか」。
出典は agents.md 標準 (https://agents.md、取得 2026-06-22)。

- README に build / test / 規約を書かない。AGENTS.md に install 説明や宣伝文を書かない。
- 見出し (H2) は英語で固定する (`## Setup` `## Test` `## Conventions`)。横断したとき揃う。
- 本文の言語は読み手に合わせる。公開 CLI / OSS は英語、個人 / 客先は日本語でよい。
- commit / branch / PR の規約は naming.md と同じ精神 (機能名 / kebab / 独自連番なし)。散文は writing-style.md。
- 各 repo の AGENTS.md は自己完結させる。hikizan の docs を参照させない (写し先に無いため)。

## AGENTS.md の節

必須は Overview / Setup / Test / Conventions / Safety。
任意は Routing (SoT が多い repo)、Tool usage (公開 CLI / ライブラリ)。

agents.md の popular sections (project overview / build & test / code style / testing / security) をこの形に畳んでいる。

## 2 つのジャンル

| ジャンル | AGENTS.md の中身 | 例 |
| --- | --- | --- |
| repo 貢献ガイド | この repo でどう作業するか | アプリ / サイト / plugin |
| tool 利用マニュアル | この公開 CLI を agent がどう使うか | pdfmint / sitesnap |

後者は Tool usage 節 (When to use / Output / Error codes) を主にする変種。
どちらも README との役割分離は同じ。

## 点検

- README と AGENTS.md で同じ内容を二度書いていないか。
- H2 が英語で、必須 5 節があるか。
- Safety に破壊的操作 / デプロイの確認点があるか。
- AGENTS.md が hikizan の docs に依存せず単体で読めるか。
