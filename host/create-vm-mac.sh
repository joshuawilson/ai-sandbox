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

VM_DIR="$BASE/vm"
ISO="$VM_DIR/fedora.iso"

mkdir -p "$VM_DIR"

echo "== AI Sandbox VM Setup (Mac / Tart) =="

# --- Kickstart ---
if [[ -f "$BASE/secrets/vm-password.env" && -f "$BASE/secrets/ssh/id_ed25519.pub" ]]; then
  echo "Generating ks.cfg..."
  "$BASE/host/generate-ks-mac.sh" || true
else
  echo "Skipping generate-ks-mac.sh — add secrets/vm-password.env and secrets/ssh first."
fi

# --- Download ISO ---
if [[ ! -f "$ISO" ]]; then
  echo "Downloading Fedora aarch64 netinstall ISO..."
  curl -L "$VM_ISO_URL" -o "$ISO"
else
  echo "ISO already exists: $ISO"
fi

# --- Create Tart VM ---
if tart list 2>/dev/null | grep -q "$VM_NAME"; then
  echo "Tart VM '$VM_NAME' already exists. Delete first with: tart delete $VM_NAME"
  exit 1
fi

echo "Creating Tart VM: $VM_NAME (disk ${VM_DISK_GB}G, ${VM_VCPUS} CPUs, ${VM_MEMORY_MIB} MiB RAM)..."
tart create "$VM_NAME" --linux --disk-size "$VM_DISK_GB"
tart set "$VM_NAME" --cpu "$VM_VCPUS" --memory "$VM_MEMORY_MIB"

# --- Start HTTP kickstart server ---
KS_PID=""
cleanup() {
  if [[ -n "$KS_PID" ]] && kill -0 "$KS_PID" 2>/dev/null; then
    echo "Stopping kickstart server (PID $KS_PID)..."
    kill "$KS_PID" 2>/dev/null || true
    wait "$KS_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ -f "$BASE/ks.cfg" ]]; then
  echo "Starting kickstart HTTP server on port 8000..."
  cd "$BASE" && python3 -m http.server 8000 --bind 0.0.0.0 &
  KS_PID=$!
  cd "$BASE"
  sleep 1

  HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || echo '<your-ip>')
  echo ""
  echo "======================================"
  echo "KICKSTART INSTRUCTIONS"
  echo "======================================"
  echo ""
  echo "At the Fedora installer boot screen, press Tab (BIOS) or 'e' (EFI)"
  echo "to edit boot options. Append:"
  echo ""
  echo "  inst.ks=http://${HOST_IP}:8000/ks.cfg"
  echo ""
  echo "(If en0 is not your active interface, use your LAN IP instead.)"
  echo "======================================"
  echo ""
else
  echo "No ks.cfg found — skipping HTTP kickstart server."
  echo "Install Fedora manually, then run config/install-inside-vm.sh in the guest."
fi

# --- Boot VM with ISO + virtiofs ---
echo "Booting VM from ISO with virtiofs shares..."
echo "(Close the VM window or shut down the guest to return to this terminal.)"
echo ""
tart run "$VM_NAME" \
  --disk "$ISO" \
  --directory host-config:"$BASE/config":ro \
  --directory host-secrets:"$BASE/secrets":ro \
  --directory host-workspace:"$BASE/workspace"

echo ""
echo "VM session ended."
echo "If Fedora installed successfully, start the VM for first-boot provisioning:"
echo "  ./start-vm.sh"
echo ""
echo "On first boot: ai-sandbox-virtiofs-mounts.service (~/ai-sandbox symlinks),"
echo "then ai-sandbox-firstboot.service (install-inside-vm after network)."
echo "Username: ai"
