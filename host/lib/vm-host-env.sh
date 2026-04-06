# shellcheck shell=bash
# Load host/vm-host.env from repo root. Bash-compatible KEY=value lines only (# comments OK).

vm_host_env_file() {
  printf '%s/host/vm-host.env' "${1:?}"
}

vm_host_env_load() {
  local base="$1"
  local f
  f="$(vm_host_env_file "$base")"
  [[ -f "$f" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
}

# Defaults after optional vm-host.env (Linux virt-install).
vm_host_apply_defaults_linux() {
  VM_NAME="${VM_NAME:-ai-sandbox}"
  VM_DISK_GB="${VM_DISK_GB:-80}"
  VM_MEMORY_MIB="${VM_MEMORY_MIB:-32768}"
  VM_VCPUS="${VM_VCPUS:-8}"
  VM_CPU_MODE="${VM_CPU_MODE:-host-model}"
  FEDORA_VER="${FEDORA_VER:-43}"
  VM_DIR="${VM_DIR:-/var/lib/libvirt/images}"
  VM_LIBVIRT_NETWORK="${VM_LIBVIRT_NETWORK:-default}"
  LOCATION_URL="${LOCATION_URL:-https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VER}/Everything/x86_64/os/}"
}

# Defaults for Mac (UTM) / shared with create-vm-mac.sh
vm_host_apply_defaults_mac() {
  VM_NAME="${VM_NAME:-ai-sandbox}"
  VM_DISK_GB="${VM_DISK_GB:-80}"
  VM_MEMORY_MIB="${VM_MEMORY_MIB:-32768}"
  VM_VCPUS="${VM_VCPUS:-8}"
  FEDORA_VER="${FEDORA_VER:-43}"
  VM_ISO_URL="${VM_ISO_URL:-https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VER}/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-43-1.6.iso}"
}
