#!/usr/bin/env bash
# Stop or remove the libvirt/KVM sandbox VM (Fedora host). Default domain: ai-sandbox (or VM_NAME from host/vm-host.env)
set -euo pipefail

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
# shellcheck source=lib/vm-host-env.sh
source "$_HS_HOST_DIR/lib/vm-host-env.sh"
BASE="$(sandbox_repo_root)"
vm_host_env_load "$BASE"
VM_NAME="${VM_NAME:-ai-sandbox}"
DOMAIN="${VIRSH_DOMAIN:-$VM_NAME}"
URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"
VM_DIR="${VM_DIR:-/var/lib/libvirt/images}"
DISK="$VM_DIR/${DOMAIN}.qcow2"

shutdown_first=false
remove=false
for arg in "$@"; do
  case "$arg" in
    --shutdown | -s) shutdown_first=true ;;
    --remove | -r | --cleanup) remove=true ;;
    -h | --help)
      echo "Usage: $(basename "$0") [--shutdown] [--remove]"
      echo "  (default)   Force power off: virsh destroy (domain + disk kept)."
      echo "  --shutdown  Try ACPI shutdown first, then destroy if still running (~60s)."
      echo "  --remove    After stop: virsh undefine and remove storage (full cleanup for reinstall)."
      echo ""
      echo "Environment: VIRSH_DOMAIN (default: VM_NAME from host/vm-host.env or ai-sandbox), LIBVIRT_DEFAULT_URI, VM_DIR"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v virsh >/dev/null 2>&1; then
  echo "virsh not found. Run ./setup-host.sh first." >&2
  exit 1
fi

if ! virsh -c "$URI" dominfo "$DOMAIN" &>/dev/null; then
  echo "No domain '$DOMAIN' (URI: $URI)." >&2
  if [[ "$remove" == true ]] && [[ -f "$DISK" ]]; then
    echo "Removing leftover disk: $DISK" >&2
    sudo rm -f "$DISK"
  fi
  exit 0
fi

if [[ "$shutdown_first" == true ]]; then
  echo "Shutting down $DOMAIN (ACPI)..."
  virsh -c "$URI" shutdown "$DOMAIN" 2>/dev/null || true
  for _ in $(seq 1 30); do
    state=$(virsh -c "$URI" domstate "$DOMAIN" 2>/dev/null || echo "gone")
    if [[ "$state" != "running" ]]; then
      echo "Guest stopped (state: $state)."
      break
    fi
    sleep 2
  done
fi

state=$(virsh -c "$URI" domstate "$DOMAIN" 2>/dev/null || echo "gone")
if [[ "$state" == "running" ]]; then
  echo "Force-stopping $DOMAIN..."
  virsh -c "$URI" destroy "$DOMAIN"
else
  echo "Domain $DOMAIN is not running."
fi

if [[ "$remove" == true ]]; then
  echo "Removing domain definition and storage..."
  # create-vm-linux.sh creates a 'clean' snapshot; undefine fails without --snapshots-metadata.
  if ! virsh -c "$URI" undefine "$DOMAIN" --snapshots-metadata --remove-all-storage; then
    echo "virsh undefine failed (see errors above). Try: virsh -c $URI snapshot-list $DOMAIN" >&2
    exit 1
  fi
  sudo rm -f "$DISK"
  echo "Cleanup done. Recreate with: host/create-vm-linux.sh"
fi
