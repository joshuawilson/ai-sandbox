#!/usr/bin/env bash
# Returning to work: same as start-dev.sh (default project container + Cursor).
# Use `bash …/start-dev.sh` so +x is not required (config/ is often virtiofs read-only from the host).
_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$_dir/start-dev.sh" "$@"
