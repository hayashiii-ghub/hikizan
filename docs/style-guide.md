---
title: hikizan style guide
description: skill 本文 / ドキュメントの記述ルール (自然な日本語 / 命名規約 / 引き算原則の参照)
---

# style guide

skill 本文 / ドキュメントを書くときのルール集。新しい skill や doc を追加するときの参照点。

## 自然な日本語

下記の中国語起源の表現は使わない:

| 使わない | 使う |
|---|---|
| 起草 | ドラフト / 下書き |
| 最小一歩 | 最小ステップ |
| 押し戻し | 反論 / 差し戻し |

ただし「横展開」は IT 業界で定着しているため使用可。

## 命名規約

- PR / branch / step を独自連番 (PR-1 等) で呼ばない。issue 名 / 機能名 / branch 名で呼ぶ
- 重複時のみ `-v2`, `-v3` ... のサフィックスを使う (バージョン番号としての連番、`-alt` は使わない)
- 詳細: [AGENTS.md 作業ルール 7](../AGENTS.md) / 各 SKILL.md の Hard Rules

## 引き算原則

- 推奨度は `N/10 + 1 行根拠` の形式 (数値だけだと検証不能)
- 3 案以上は出さない (paralysis 防止)
- 通常検討モードの出力には `Minimal Approach:` セクションを必ず添える (素直な規模との対比)
- 詳細: kouchiku §3.8 / `skills/kouchiku/references/minimal-approach.md` (Phase 2 step 2-5 で切り出し予定)

## 言語ポリシー

agent の応答は問い合わせ言語に合わせる。日本語の問い合わせには自然文 (説明 / 要約 / 提案理由 / 質問) を日本語で返す。skill 内の英語 label と技術用語 (TDD, mock, RED/GREEN/REFACTOR/PRUNE 等) はそのまま残す。
