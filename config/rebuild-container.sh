#!/usr/bin/env bash
set -e

IMAGE_NAME="ai-dev"

echo "Removing old container images..."

podman rmi "$IMAGE_NAME" || true

echo "Rebuilding..."

~/ai-sandbox/config/build-container.sh
