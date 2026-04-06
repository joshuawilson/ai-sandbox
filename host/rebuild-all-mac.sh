#!/usr/bin/env bash
set -e

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
# shellcheck source=lib/vm-host-env.sh
source "$_HS_HOST_DIR/lib/vm-host-env.sh"
BASE="$(sandbox_repo_root)"
vm_host_env_load "$BASE"
vm_host_apply_defaults_mac

echo "=== AI SANDBOX REBUILD (MAC) ==="

echo "[1/4] Generating Kickstart..."
"$BASE/host/generate-ks-mac.sh"

echo "[2/4] Removing old VM disk..."
rm -f "$BASE/vm/${VM_NAME}.qcow2"

echo "[3/4] Recreating disk + ISO..."
"$BASE/host/create-vm-mac.sh"

echo ""
echo "======================================"
echo "Manual step required:"
echo "Open UTM and reinstall VM using new disk"
echo "======================================"
