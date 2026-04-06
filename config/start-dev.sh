#!/usr/bin/env bash
# If you get "Permission denied" on this path, run: bash ~/ai-sandbox/config/start-dev.sh
# (config/ is often virtiofs read-only; the file mode comes from the host git checkout.)
set -e

SANDBOX=~/ai-sandbox
export SANDBOX

# Use the first project under ~/ai-sandbox/workspace (lexicographic), or "default" if empty.
FIRST=$("$SANDBOX/config/first-project-name.sh")
mkdir -p "$SANDBOX/workspace/$FIRST"

bash "$SANDBOX/config/start-container.sh" --detach "$FIRST" &

sleep 3

PROJECT_DIR="$SANDBOX/workspace/$FIRST"
if command -v cursor >/dev/null 2>&1; then
  cursor "$PROJECT_DIR"
elif [ -x /usr/bin/cursor ]; then
  /usr/bin/cursor "$PROJECT_DIR"
elif [ -x /usr/share/cursor/cursor ]; then
  /usr/share/cursor/cursor "$PROJECT_DIR"
else
  echo "Cursor CLI not found (install via install-inside-vm.sh). Project: $PROJECT_DIR" >&2
  echo "Open that folder manually in Cursor, or add Cursor's bin directory to PATH." >&2
  exit 1
fi
