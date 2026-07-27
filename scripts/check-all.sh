#!/usr/bin/env bash
# Hook、スキル、生成物、シェルをまとめて検査する。
# 人とCIが同じ入口で全体の状態を確認するための開発用スクリプト。
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rc=0
bash "$ROOT/hooks/tests/run.sh" || rc=1
bash "$ROOT/scripts/test-skill-recipes.sh" || rc=1
bash "$ROOT/scripts/check-consistency.sh" || rc=1
bash "$ROOT/scripts/gen-routing.sh" --check || rc=1
bash "$ROOT/scripts/gen-trigger-docs.sh" --check || rc=1
bash "$ROOT/scripts/gen-manifests.sh" --check || rc=1
bash "$ROOT/scripts/gen-contract.sh" --check || rc=1
bash "$ROOT/scripts/gen-visual-contract.sh" --check || rc=1
if command -v shellcheck >/dev/null 2>&1; then
  (cd "$ROOT" && git ls-files '*.sh' | xargs shellcheck -x -S warning) || rc=1
else
  echo "skip: shellcheck not found (CI では実行される)"
fi
if [ "$rc" -eq 0 ]; then echo "✔ check-all: all suites passed"; else echo "✘ check-all: failures above"; fi
exit "$rc"
