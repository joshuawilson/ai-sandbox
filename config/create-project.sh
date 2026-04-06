#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
  echo "Usage: create-project.sh <project-name>"
  exit 1
fi

NAME=$1

# Same isolation flags as start-container.sh (detached)
exec ~/ai-sandbox/config/start-container.sh --detach "$NAME"
