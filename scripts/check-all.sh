#!/usr/bin/env bash
# Single entry point for every hikizan check: hook tests + consistency lint +
# trigger-table freshness. CI and humans run only this.
#   bash scripts/check-all.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rc=0
bash "$ROOT/hooks/tests/run.sh" || rc=1
bash "$ROOT/scripts/check-consistency.sh" || rc=1
bash "$ROOT/scripts/gen-trigger-docs.sh" --check || rc=1
bash "$ROOT/scripts/gen-cursor-rule.sh" --check || rc=1
bash "$ROOT/scripts/gen-manifests.sh" --check || rc=1
if [ "$rc" -eq 0 ]; then echo "✔ check-all: all suites passed"; else echo "✘ check-all: failures above"; fi
exit "$rc"
