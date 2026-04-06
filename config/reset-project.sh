#!/usr/bin/env bash
# Reset a project: remove the container, wipe workspace files, start a fresh hardened container.
set -euo pipefail

NAME="${1:?usage: reset-project.sh <name>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/container.env"

podman rm -f "ai-dev-$NAME" 2>/dev/null || true
rm -rf "${WORKSPACE_ROOT:?}/$NAME"/*
mkdir -p "${WORKSPACE_ROOT}/$NAME"

exec bash "$SCRIPT_DIR/start-container.sh" --detach "$NAME"
