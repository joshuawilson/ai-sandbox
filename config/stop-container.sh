#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: stop-container.sh <project-name>"
  exit 1
fi

NAME="$1"

podman stop "ai-dev-$NAME"
podman rm "ai-dev-$NAME"