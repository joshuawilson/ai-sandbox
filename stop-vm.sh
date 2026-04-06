#!/usr/bin/env bash
# Stop or remove the sandbox VM. See host/stop-vm-*.sh for flags.
ROOT="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)" in
  Linux) exec "$ROOT/host/stop-vm-linux.sh" "$@" ;;
  Darwin) exec "$ROOT/host/stop-vm-mac.sh" "$@" ;;
  *) echo "On Windows run: .\\stop-vm.ps1" >&2; exit 1 ;;
esac
