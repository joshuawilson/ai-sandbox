#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/container.env"

echo "Removing old container image: $CONTAINER_IMAGE"

podman rmi "$CONTAINER_IMAGE" || true

echo "Rebuilding..."

bash "$SCRIPT_DIR/build-container.sh"
