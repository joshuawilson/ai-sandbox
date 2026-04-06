#!/bin/bash
# Run all tests (bash + python3 only). From repo root: ./tests/run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Syntax: bash -n on all *.sh"
bash "$ROOT/tests/test_syntax.sh"
echo "    OK"

echo "==> merge-claude-bootstrap.sh"
bash "$ROOT/tests/test_merge_claude_bootstrap.sh"

echo "==> first-project-name.sh"
bash "$ROOT/tests/test_first_project_name.sh"

echo "All tests passed."
