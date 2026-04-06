#!/usr/bin/env bash
# Only host-setup entry point at repo root; other host scripts live under host/
exec "$(cd "$(dirname "$0")" && pwd)/host/$(basename "$0")" "$@"
