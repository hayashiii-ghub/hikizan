# プロジェクト文書の形式

hikizan が配る repo の AGENTS.md の正本と、README の役割境界。
AGENTS.md のスケルトンは本書末尾の「スケルトン」節。
README の節構成は各 project の裁量とし、ここでは境界だけ定める (固定の skeleton は持たない)。

## 原則

README は人間の貢献者向け、AGENTS.md は agent 向け。
意図的に分け、重複させない。
境界は「人間の貢献者に要るか / agent の作業に要るか」。
出典は agents.md 標準 (https://agents.md、取得 2026-06-22)。

- README に build / test / 規約を書かない。AGENTS.md に install 説明や宣伝文を書かない。
- README の節構成は各 project の裁量。見せ方は author が決める。守るのは役割分離と、AGENTS.md への導線 1 行だけ。
- AGENTS.md の見出し (H2) は英語で固定する (`## Setup` `## Test` `## Conventions`)。横断したとき揃う。
- 本文の言語は読み手に合わせる。公開 CLI / OSS は英語、個人 / 客先は日本語でよい。
- commit / branch / PR の規約は `skills/teishutsu/references/naming.md` と同じ精神 (機能名 / kebab / 独自連番なし)。散文は `skills/kaku/references/writing-style.md`。
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
- README から AGENTS.md への導線が 1 行あるか。
- AGENTS.md の H2 が英語で、必須 5 節があるか。
- Safety に破壊的操作 / デプロイの確認点があるか。
- AGENTS.md が hikizan の docs に依存せず単体で読めるか。

## スケルトン

````markdown
# AGENTS.md

[このリポジトリで作業する agent の入口。1 行で何の repo かを書く。]
詳細は各 SoT に従う。

## Overview

[何を解決する repo か 1-2 行。]
[主要な技術スタック (言語 / framework / ランタイム)。README と重複させない。]

## Setup

[依存のインストールと起動を、そのまま貼れるコマンドで書く。]

```bash
[依存インストール]
[dev サーバ / ビルド起動]
```

## Test

[テストの回し方。緑の最終行がどう出るかまで書く。]

```bash
[テストコマンド]
```

## Conventions

- commit / branch / PR: 機能名で呼ぶ。kebab-case。独自の連番を作らない。
- code style: [formatter / linter のコマンド。これが正]。
- [この repo 固有の言語規約があれば 1 行]。

## Safety

- [破壊的操作 / 本番デプロイ / migration など、止まって確認すべきこと]。
- [この repo 特有のハマりどころ]。

<!-- 任意: SoT が多い repo だけ。詳細はここに再掲せず参照先を指す -->
## Routing

| やること | SoT |
| --- | --- |
| [領域] | [file] |

<!-- 任意: 公開 CLI / ライブラリだけ。agent が「使う」側の情報 -->
## Tool usage

[When to use / 主要コマンド / Output 形式 / Error codes / Common tasks]
````
