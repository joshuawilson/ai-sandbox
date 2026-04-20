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

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found — brew install tart" >&2
  exit 1
fi

if ! tart list 2>/dev/null | grep -q "$VM_NAME"; then
  echo "No Tart VM named '$VM_NAME'. Run host/create-vm-mac.sh first." >&2
  exit 1
fi

echo "Starting VM '$VM_NAME' with virtiofs shares..."
echo "(Close the VM window or shut down the guest to return to this terminal.)"
tart run "$VM_NAME" \
  --directory host-config:"$BASE/config":ro \
  --directory host-secrets:"$BASE/secrets":ro \
  --directory host-workspace:"$BASE/workspace"
