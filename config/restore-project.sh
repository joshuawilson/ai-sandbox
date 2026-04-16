#!/usr/bin/env bash
# Restores from podman commit; re-applies workspace + SSH mounts (same as start-container).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source ~/ai-sandbox/config/container.env

NAME=$1

if [ -z "$NAME" ]; then
  echo "Usage: restore-project.sh <name>"
  exit 1
fi

WORKSPACE="$WORKSPACE_ROOT/$NAME"

podman rm -f "ai-dev-$NAME" || true

DEV_HOME_DIR="${HOME}/.local/share/ai-sandbox/container-home/${NAME}"
mkdir -p "$DEV_HOME_DIR"
chown "$(id -u):$(id -g)" "$DEV_HOME_DIR" 2>/dev/null || true
chmod 700 "$DEV_HOME_DIR"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/podman-claude-devhome.sh"
ai_sandbox_sync_claude_settings_to_dev_home "$DEV_HOME_DIR" "$SANDBOX"
ai_sandbox_sync_claude_userdata_to_dev_home "$DEV_HOME_DIR"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/podman-workspace-volumes.sh"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/podman-vertex-container-opts.sh"
ai_sandbox_prepare_podman_vertex

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/podman-run-common.sh"
ai_sandbox_run_dev_container "$NAME" "ai-dev-$NAME-snapshot" -dit

echo "Project restored."
