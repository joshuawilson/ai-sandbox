#!/bin/bash
# Syntax-check every *.sh under the repo (excludes .git).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failed=0

while IFS= read -r -d '' f; do
  if ! bash -n "$f" 2>&1; then
    echo "  syntax error: $f" >&2
    failed=1
  fi
done < <(find "$ROOT" -name '*.sh' -type f ! -path '*/.git/*' -print0 | sort -z)

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

if [[ "${SHELLCHECK:-}" == "1" ]] && command -v shellcheck >/dev/null 2>&1; then
  echo "  (shellcheck SHELLCHECK=1)"
  while IFS= read -r -d '' f; do
    shellcheck -x "$f" || failed=1
  done < <(find "$ROOT" -name '*.sh' -type f ! -path '*/.git/*' -print0)
fi

exit "$failed"
