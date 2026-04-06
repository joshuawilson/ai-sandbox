#!/usr/bin/env bash
set -e

SANDBOX="$HOME/ai-sandbox"
IMAGE_NAME="ai-dev"

echo "Building AI dev container..."

podman build \
  -t $IMAGE_NAME \
  -f "$SANDBOX/config/Containerfile" \
  "$SANDBOX/config"

echo "Container image built:"
echo "$IMAGE_NAME"
