#!/usr/bin/env bash
# Boot an existing VM (returning user). First-time: ./setup-host.sh (optional VM wizard) then host/create-vm-*
ROOT="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)" in
  Linux) exec "$ROOT/host/start-vm-linux.sh" "$@" ;;
  Darwin) exec "$ROOT/host/start-vm-mac.sh" "$@" ;;
  *) echo "On Windows run: .\\start-vm.ps1" >&2; exit 1 ;;
esac
