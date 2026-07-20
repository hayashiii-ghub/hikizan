#!/usr/bin/env bash
# Generate the routing reference bundled with the init skill from the
# repository-wide routing source. Skill-pack installers may copy only the
# skill directory, so init must not depend on the repository root at runtime.
#   bash scripts/gen-init-reference.sh
#   bash scripts/gen-init-reference.sh --check

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/context/routing.md"
OUT="$ROOT/skills/init/references/routing.md"

if [ "${1:-}" = "--check" ]; then
  if diff -q "$OUT" "$SRC" >/dev/null 2>&1; then
    echo "✔ skills/init/references/routing.md up to date"
  else
    echo "✘ skills/init/references/routing.md is stale — run: bash scripts/gen-init-reference.sh" >&2
    exit 1
  fi
else
  mkdir -p "$(dirname "$OUT")"
  cp "$SRC" "$OUT"
  echo "✔ wrote skills/init/references/routing.md"
fi
