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
