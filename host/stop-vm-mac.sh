#!/usr/bin/env bash
set -euo pipefail

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
# shellcheck source=lib/vm-host-env.sh
source "$_HS_HOST_DIR/lib/vm-host-env.sh"
BASE="$(sandbox_repo_root)"
vm_host_env_load "$BASE"
vm_host_apply_defaults_mac

remove=false

for arg in "$@"; do
  case "$arg" in
    --remove | -r | --cleanup) remove=true ;;
    -h | --help)
      echo "Usage: $(basename "$0") [--remove]"
      echo "  Stops the Tart VM named '$VM_NAME'."
      echo "  --remove  Delete the VM and its disk entirely."
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found — brew install tart" >&2
  exit 1
fi

if ! tart list 2>/dev/null | grep -q "$VM_NAME"; then
  echo "No Tart VM named '$VM_NAME'."
  exit 0
fi

echo "Stopping VM '$VM_NAME'..."
tart stop "$VM_NAME" 2>/dev/null || true

if [[ "$remove" == true ]]; then
  echo "Deleting VM '$VM_NAME' and its disk..."
  tart delete "$VM_NAME" 2>/dev/null || true
  echo "VM deleted."
  ISO="$BASE/vm/fedora.iso"
  if [[ -f "$ISO" ]]; then
    echo "ISO cache retained at $ISO (delete manually if not needed)."
  fi
else
  echo "VM stopped. Start again with: ./start-vm.sh"
fi
