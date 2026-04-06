#!/usr/bin/env bash
# One entry point for Fedora + macOS: run the right install script, then the host check.
# Windows: use setup-host.ps1 (PowerShell as Administrator).
# Lives under host/; repo root setup-host.sh is a thin wrapper.
set -euo pipefail

HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$HOST_DIR/.." && pwd)"
cd "$BASE" || exit 1

CHECK_ONLY=false
CONFIGURE_VM=true
for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=true ;;
    --skip-vm-config) CONFIGURE_VM=false ;;
    -h | --help)
      cat <<EOF
Usage: $0 [--check-only] [--skip-vm-config]

  Installs host dependencies (unless --check-only), then runs the platform check.

  Fedora: install-virt-linux.sh → check-host-fedora.sh
  macOS:  install-virt-mac.sh → check-host-mac.sh

  After a successful check (interactive terminal only), you are offered
  host/configure-vm-host.sh — VM disk/RAM/CPUs and an auto-generated guest password
  (secrets/vm-password.env). Run that before host/create-vm-* so sizing is set
  before the guest is built. Skip with --skip-vm-config or SKIP_VM_CONFIGURE=1.

  First VM (Fedora): after setup, run host/create-vm-linux.sh — kickstart install
  (needs sudo, network, long install).

  After libvirt adds you to group 'libvirt' on Fedora, log out and back in, then:
    $0 --check-only

  On Windows use:  .\\setup-host.ps1
EOF
      exit 0
      ;;
  esac
done

maybe_run_configure_vm_host() {
  if [[ "${SKIP_VM_CONFIGURE:-}" != "" ]]; then
    return 0
  fi
  if [[ "$CONFIGURE_VM" != true ]]; then
    return 0
  fi
  if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    echo ""
    echo "Non-interactive session: skipped VM config wizard. Before create-vm run:"
    echo "  ./host/configure-vm-host.sh"
    echo "(Or set SKIP_VM_CONFIGURE=1 to silence this note.)"
    return 0
  fi
  local reply
  read -r -p "Configure VM sizing and guest password (host/vm-host.env + secrets/vm-password.env)? [Y/n] " reply || true
  case "${reply:-y}" in
    y | Y | yes | "")
      "$HOST_DIR/configure-vm-host.sh"
      ;;
    *)
      echo "Skipped. Run ./host/configure-vm-host.sh before host/create-vm-* when ready."
      ;;
  esac
}

os=$(uname -s)
if [[ "$os" == "Linux" ]]; then
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
  fi
  if [[ "${ID:-}" != "fedora" ]]; then
    echo "Automated install is supported on Fedora hosts. Detected ID=${ID:-unknown}." >&2
    echo "On Fedora run this script; on other distros install KVM/libvirt yourself and run host/check-host-fedora.sh if applicable." >&2
    exit 1
  fi
  if [[ "$CHECK_ONLY" == true ]]; then
    exec "$HOST_DIR/check-host-fedora.sh"
  fi
  "$HOST_DIR/install-virt-linux.sh"
  echo ""
  "$HOST_DIR/check-host-fedora.sh"
  maybe_run_configure_vm_host
elif [[ "$os" == "Darwin" ]]; then
  if [[ "$CHECK_ONLY" == true ]]; then
    exec "$HOST_DIR/check-host-mac.sh"
  fi
  "$HOST_DIR/install-virt-mac.sh"
  echo ""
  "$HOST_DIR/check-host-mac.sh"
  maybe_run_configure_vm_host
else
  echo "Unsupported OS: $os. On Windows run: .\\setup-host.ps1 (elevated PowerShell)" >&2
  exit 1
fi
