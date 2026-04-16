#!/usr/bin/env bash
# Shell into a running ai-dev container
set -e

if [ -z "$1" ]; then
  echo "Usage: shell-into-container.sh <project-name>"
  echo ""
  echo "Opens an interactive shell in the running ai-dev-<project-name> container."
  echo ""
  echo "Example:"
  echo "  bash ~/ai-sandbox/config/shell-into-container.sh default"
  exit 1
fi

NAME="$1"
CTR="ai-dev-$NAME"

if ! podman inspect --type container "$CTR" &>/dev/null; then
  echo "Error: Container $CTR does not exist or is not running." >&2
  echo "" >&2
  echo "Available containers:" >&2
  podman ps -a --filter "name=ai-dev-" --format "{{.Names}} ({{.Status}})" >&2
  exit 1
fi

exec podman exec -it "$CTR" /bin/bash
