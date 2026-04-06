#!/usr/bin/env bash
# Saves container rootfs only; bind-mounted /workspace is not part of the image.
# After restore, ensure the same -v /workspace mapping is used.

NAME=$1

if [ -z "$NAME" ]; then
  echo "Usage: snapshot-project <name>"
  exit 1
fi

podman commit "ai-dev-$NAME" "ai-dev-$NAME-snapshot"

echo "Snapshot saved: ai-dev-$NAME-snapshot"
