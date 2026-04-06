#!/usr/bin/env bash
set -e

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
# shellcheck source=lib/vm-host-env.sh
source "$_HS_HOST_DIR/lib/vm-host-env.sh"
BASE="$(sandbox_repo_root)"
vm_host_env_load "$BASE"
vm_host_apply_defaults_linux

echo "=== AI SANDBOX FULL REBUILD ==="

echo "[1/4] Generating Kickstart..."
"$BASE/host/generate-ks-fedora.sh"

echo "[2/4] Destroying old VM..."
virsh destroy "$VM_NAME" 2>/dev/null || true
if virsh dominfo "$VM_NAME" &>/dev/null; then
  # Snapshots (e.g. 'clean' from create-vm-linux) block plain virsh undefine.
  virsh undefine "$VM_NAME" --snapshots-metadata --remove-all-storage
fi

echo "[3/4] Removing disk..."
sudo rm -f "$VM_DIR/${VM_NAME}.qcow2"

echo "[4/4] Creating VM..."
"$BASE/host/create-vm-linux.sh"

echo ""
echo "======================================"
echo "After install, first boot: ai-sandbox-virtiofs-mounts.service (~/ai-sandbox),"
echo "then ai-sandbox-firstboot.service (install-inside-vm.sh). See spec/how/bootstrap.md."
echo "======================================"
