#!/bin/bash

set -e

SANDBOX=~/ai-sandbox
SANDBOX="$(cd "$SANDBOX" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source ~/ai-sandbox/config/container.env

DETACH=false
if [ "${1:-}" = "--detach" ]; then
  DETACH=true
  shift
fi

NAME="${1:-default}"

WORKSPACE="$WORKSPACE_ROOT/$NAME"

mkdir -p "$WORKSPACE"

# Self-heal: copy from virtiofs if install-inside-vm was skipped or used an older script.
SANDBOX_KEY="$SANDBOX/secrets/ssh/id_ed25519"
SANDBOX_PUB="$SANDBOX/secrets/ssh/id_ed25519.pub"
if [[ ! -r "$HOME/.ssh/id_ed25519" && -r "$SANDBOX_KEY" ]]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  install -m 600 "$SANDBOX_KEY" "$HOME/.ssh/id_ed25519"
  [[ -r "$SANDBOX_PUB" ]] && install -m 644 "$SANDBOX_PUB" "$HOME/.ssh/id_ed25519.pub"
fi
if [[ ! -r "$HOME/.ssh/id_ed25519" ]]; then
  echo "Missing ~/.ssh/id_ed25519 (needed for git in the dev container)." >&2
  echo "Run:  bash ~/ai-sandbox/config/install-inside-vm.sh" >&2
  echo "On the host ensure secrets/ssh/id_ed25519 exists (install-virt-linux.sh or secrets/gen-ssh-key.sh)." >&2
  exit 1
fi

CTR="ai-dev-$NAME"
if podman inspect --type container "$CTR" &>/dev/null; then
  echo "Container $CTR already exists. Remove it first: podman rm -f $CTR" >&2
  exit 1
fi

IMAGE_EXISTS=$(podman images -q "$CONTAINER_IMAGE")

if [ -z "$IMAGE_EXISTS" ]; then
    echo "Container image not found. Building..."
    ~/ai-sandbox/config/build-container.sh
fi

# Writable home overlay (image /home/dev is hidden). Guest-local dir must match the UID that actually
# runs in the container. The image sets USER dev (UID 1000); kickstart often gives ai a non-1000 UID.
# With --userns=keep-id, Podman can still honor the image USER → EACCES on this 700 dir and on /workspace.
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

if ! ls -la "$WORKSPACE" >/dev/null 2>&1; then
  echo "ai-sandbox: cannot access $WORKSPACE as $(id -un) (uid $(id -u)). Fix permissions/ownership on host or guest, then retry." >&2
  exit 1
fi

RUN_FLAGS=()
if [ "$DETACH" = true ]; then
  RUN_FLAGS+=(-d)
else
  RUN_FLAGS+=(-it)
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/podman-run-common.sh"
ai_sandbox_run_dev_container "$NAME" "$CONTAINER_IMAGE" "${RUN_FLAGS[@]}"
