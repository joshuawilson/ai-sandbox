#!/usr/bin/env bash
# Apply ACLs + SELinux virt_content_t so libvirt's QEMU user can read this repo over virtiofs.
# Required when the checkout lives under /home (typical git clone). Idempotent.
#
# Usage (from repo root):
#   ./host/fix-virtiofs-qemu-access.sh
#
# Called automatically by host/install-virt-linux.sh and host/create-vm-linux.sh.
set -euo pipefail

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
# shellcheck source=lib/virtiofs-qemu-access.sh
source "$_HS_HOST_DIR/lib/virtiofs-qemu-access.sh"

BASE="$(sandbox_repo_root)"

echo "AI Sandbox: preparing virtiofs paths for libvirt QEMU (repo: $BASE)"
ensure_qemu_access_for_virtiofs "$BASE"

if id qemu &>/dev/null \
  && sudo -u qemu test -r "$BASE/config/ensure-sandbox-mounts.sh" 2>/dev/null \
  && sudo -u qemu test -r "$BASE/secrets" 2>/dev/null \
  && sudo -u qemu test -x "$BASE/secrets" 2>/dev/null \
  && sudo -u qemu test -r "$BASE/workspace" 2>/dev/null \
  && sudo -u qemu test -x "$BASE/workspace" 2>/dev/null; then
  echo "OK: user qemu can access config, secrets, and workspace (virtiofs should work in the guest)."
else
  echo "Warning: could not verify qemu access; check errors above." >&2
  exit 1
fi
