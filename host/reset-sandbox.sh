#!/usr/bin/env bash
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
SNAPSHOT="${VIRSH_SNAPSHOT:-clean}"

virsh destroy "$DOMAIN" 2>/dev/null || true
virsh snapshot-revert "$DOMAIN" "$SNAPSHOT"
virsh start "$DOMAIN"
