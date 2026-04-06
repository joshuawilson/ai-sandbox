#!/usr/bin/env bash
# Print the first project name under ~/ai-sandbox/workspace (lexicographic by folder name).
# Skips hidden directories (e.g. .ai-sandbox-private). If none exist, print: default
set -euo pipefail

SANDBOX="${SANDBOX:-$HOME/ai-sandbox}"
proj_root="$SANDBOX/workspace"

if [[ ! -d "$proj_root" ]]; then
  echo "default"
  exit 0
fi

declare -a names=()
shopt -s nullglob
for p in "$proj_root"/*; do
  [[ -d "$p" ]] || continue
  b=$(basename "$p")
  [[ "$b" == .* ]] && continue
  names+=("$b")
done

if ((${#names[@]} == 0)); then
  echo "default"
  exit 0
fi

printf '%s\n' "${names[@]}" | sort | head -n1
