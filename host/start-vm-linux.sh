#!/usr/bin/env bash
# Start an existing libvirt VM (Fedora host). Default domain: VM_NAME from host/vm-host.env or ai-sandbox
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

if ! command -v virsh >/dev/null 2>&1; then
  echo "virsh not found. Run ./setup-host.sh first." >&2
  exit 1
fi

if ! virsh -c "$URI" dominfo "$DOMAIN" &>/dev/null; then
  echo "No libvirt domain '$DOMAIN' (URI: $URI). Create the VM with host/create-vm-linux.sh first." >&2
  exit 1
fi

STATE=$(virsh -c "$URI" domstate "$DOMAIN" 2>/dev/null || echo "unknown")
if [[ "$STATE" == "running" ]]; then
  echo "VM '$DOMAIN' is already running."
else
  virsh -c "$URI" start "$DOMAIN"
  echo "Started VM '$DOMAIN'."
fi

if command -v virt-viewer >/dev/null 2>&1; then
  echo "Opening SPICE viewer..."
  virt-viewer -c "$URI" "$DOMAIN" &
else
  echo "virt-viewer not found; connect manually (virt-manager, SSH, etc.)."
fi
