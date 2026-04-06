#!/usr/bin/env bash
# Ensure ~/.claude/settings.json exists with bypassPermissions (YOLO). Run on the guest if the file is empty
# or missing (e.g. empty secrets/claude-settings.json was copied during install).
set -euo pipefail

FORCE=0
if [[ "${1:-}" == --force ]]; then
  FORCE=1
  shift
fi

SANDBOX="${1:-$HOME/ai-sandbox}"
SANDBOX="$(cd "$SANDBOX" && pwd)"
TEMPLATE="$SANDBOX/config/claude-code.settings.json"

mkdir -p "$HOME/.claude"

if [[ "$FORCE" == 1 ]]; then
  [[ -f "$TEMPLATE" ]] || {
    echo "missing $TEMPLATE" >&2
    exit 1
  }
  install -m 600 "$TEMPLATE" "$HOME/.claude/settings.json"
  echo "Wrote $HOME/.claude/settings.json from $TEMPLATE (--force)"
  exit 0
fi

if [[ -f "$HOME/.claude/settings.json" && -s "$HOME/.claude/settings.json" ]]; then
  echo "OK: $HOME/.claude/settings.json already exists and is non-empty (not overwriting)."
  exit 0
fi

[[ -f "$TEMPLATE" ]] || {
  echo "missing $TEMPLATE" >&2
  exit 1
}
install -m 600 "$TEMPLATE" "$HOME/.claude/settings.json"
echo "Wrote $HOME/.claude/settings.json from template (was missing or empty)."
