#!/usr/bin/env bash
set -e
# x86_64 ISO by default. On Apple Silicon, use a Fedora aarch64 image and set VM_ISO_URL in host/vm-host.env.

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
DISK="$VM_DIR/$VM_NAME.qcow2"

ISO_URL="$VM_ISO_URL"

mkdir -p "$VM_DIR"

echo "== AI Sandbox VM Setup (Mac) =="

if [[ -f "$BASE/secrets/vm-password.env" && -f "$BASE/secrets/ssh/id_ed25519.pub" ]]; then
  echo "Generating ks.cfg..."
  "$BASE/host/generate-ks-mac.sh" || true
else
  echo "Skipping generate-ks-mac.sh — add secrets/vm-password.env and secrets/ssh first."
fi

# Download ISO
if [[ ! -f "$ISO" ]]; then
  echo "Downloading Fedora ISO..."
  curl -L "$ISO_URL" -o "$ISO"
else
  echo "ISO already exists."
fi

# Create disk
if [[ ! -f "$DISK" ]]; then
  echo "Creating VM disk..."
  qemu-img create -f qcow2 "$DISK" "${VM_DISK_GB}G"
else
  echo "Disk already exists."
fi

echo ""
echo "======================================"
echo "UTM — manual steps"
echo "======================================"
echo ""
echo "1. Open UTM → New → Virtualize → Linux"
echo "2. Boot ISO: $ISO"
echo "3. Disk: import existing → $DISK"
echo ""
echo "Recommended in UTM: RAM ≈ ${VM_MEMORY_MIB} MiB, ${VM_VCPUS} CPUs (from host/vm-host.env), NAT, VirtIO GPU."
echo ""
echo "=== Kickstart (optional unattended install) ==="
echo "On this Mac, from $BASE run:"
echo "  ./tools/serve-kickstart.sh"
echo "At the Fedora installer boot screen, edit options and add:"
echo "  inst.ks=http://\$(ipconfig getifaddr en0):8000/ks.cfg"
echo "(Use your LAN IP if different; allow firewall for TCP 8000.)"
echo ""
echo "=== Shared folder (after install) ==="
echo "In UTM: VM Settings → Shared Directory — add your host folder:"
echo "  $BASE"
echo "Then in the guest mount it (virtio-9p path depends on UTM) or use rsync/scp to sync config/."
echo "Alternatively use SMB from a Windows/Linux host per spec/how/bootstrap.md."
echo ""
echo "=== If install finishes without kickstart ==="
echo "Copy this repo into the guest or mount the share, then:"
echo "  sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai   # or configure CIFS first — config/cifs.env.example"
echo "  ~/ai-sandbox/config/install-inside-vm.sh"
echo ""
echo "=== If you used HTTP kickstart but UTM has no virtiofs tags ==="
echo "ai-sandbox-firstboot.service will fail until the guest can see host config/."
echo "Set up SMB (Windows host -CreateSmbShare, or macOS file sharing) and CIFS per config/cifs.env.example,"
echo "then: sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai && ~/ai-sandbox/config/install-inside-vm.sh"
echo "======================================"
