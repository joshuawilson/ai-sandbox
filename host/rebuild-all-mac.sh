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

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found — brew install tart" >&2
  exit 1
fi

echo "[1/3] Removing existing VM..."
tart stop "$VM_NAME" 2>/dev/null || true
tart delete "$VM_NAME" 2>/dev/null || true
rm -f "$BASE/vm/fedora.iso"

echo "[2/3] Generating Kickstart..."
"$BASE/host/generate-ks-mac.sh"

echo "[3/3] Creating new VM..."
"$BASE/host/create-vm-mac.sh"
