#!/bin/bash
set -e

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"
# shellcheck source=lib/virtiofs-qemu-access.sh
source "$_HS_HOST_DIR/lib/virtiofs-qemu-access.sh"
# shellcheck source=lib/vm-host-env.sh
source "$_HS_HOST_DIR/lib/vm-host-env.sh"

vm_host_env_load "$BASE"
vm_host_apply_defaults_linux

# libvirt runs qemu as a separate user; disks under $HOME are often not traversable (permission denied).
# Default: standard libvirt image pool (readable by qemu). Set VM_DIR in host/vm-host.env or host/configure-vm-host.sh.
DISK="$VM_DIR/$VM_NAME.qcow2"
KS="$BASE/ks.cfg"

# Network installer tree: Fedora publishes vmlinuz/initrd/repodata under linux/releases/<ver>/Everything/x86_64/os/
# (The old .../Workstation/x86_64/os/ path is not present on current mirrors — 404.)
# Kickstart still installs the desktop via @workstation-product-environment in host/ks.template.cfg.
# Verify versions: https://dl.fedoraproject.org/pub/fedora/linux/releases/
# Tunables: host/vm-host.env (see vm-host.env.example) or host/configure-vm-host.sh — disk, RAM, vCPUs, CPU mode, FEDORA_VER, LOCATION_URL, VM_DIR, VM_LIBVIRT_NETWORK.
#
# We use --location + --initrd-inject because virt-install documents initrd injection for the
# initrd fetched from --location, not from --cdrom; that is why this script does not download
# the full Workstation ISO here. For an offline ISO install, use the ISO in virt-manager and
# supply kickstart another way (e.g. inst.ks on a URL/USB), or keep a separate manual path.

case "$VM_DIR" in
  "$HOME"/* | /home/*)
    echo "Warning: VM_DIR is under a home directory; qemu often cannot open the disk (use default /var/lib/libvirt/images, or setfacl -m u:qemu:rx on each path component)." >&2
    ;;
esac

if [ ! -f "$BASE/secrets/ssh/id_ed25519.pub" ]; then
  echo "Missing sandbox SSH public key. Run host/install-virt-linux.sh first." >&2
  exit 1
fi
if [ ! -f "$BASE/secrets/ssh/id_ed25519" ]; then
  echo "Missing sandbox SSH private key: $BASE/secrets/ssh/id_ed25519" >&2
  echo "Run host/install-virt-linux.sh or secrets/gen-ssh-key.sh (guest install-inside-vm copies it into ~/.ssh for Podman)." >&2
  exit 1
fi

echo "Generating kickstart..."
"$BASE/host/generate-ks-fedora.sh"

if [ ! -f "$KS" ]; then
  echo "Missing $KS after generation." >&2
  exit 1
fi

# Let virt-install create the qcow2 under VM_DIR (correct owner for qemu); do not qemu-img into $HOME.
disk_arg="path=$DISK,size=${VM_DISK_GB},format=qcow2,bus=virtio"
if [ -f "$DISK" ]; then
  disk_arg="path=$DISK,format=qcow2,bus=virtio"
fi

echo "Starting unattended install from: $LOCATION_URL"
echo "VM disk: $DISK (${VM_DISK_GB} GiB) — RAM ${VM_MEMORY_MIB} MiB, ${VM_VCPUS} vCPUs, cpu ${VM_CPU_MODE}"
echo "(Requires outbound HTTPS to Fedora mirrors.)"

ensure_qemu_access_for_virtiofs "$BASE" || exit 1

# virtiofs needs shared guest RAM (memfd) for virtiofsd vhost-user; without it virt-install
# falls back to virtio-9p and the guest must use mount -t 9p, not virtiofs (see libvirt
# kbase virtiofs.html). Force driver.type=virtiofs so we never silently get 9p.
sudo virt-install \
  --connect qemu:///system \
  --name "$VM_NAME" \
  --memory "$VM_MEMORY_MIB" \
  --memorybacking=source.type=memfd,access.mode=shared \
  --vcpus "$VM_VCPUS" \
  --cpu "$VM_CPU_MODE" \
  --disk "$disk_arg" \
  --os-variant "fedora${FEDORA_VER}" \
  --location "$LOCATION_URL" \
  --initrd-inject="$KS" \
  --extra-args "inst.ks=file:/ks.cfg" \
  --graphics spice \
  --video virtio \
  --network "network=${VM_LIBVIRT_NETWORK}" \
  --filesystem "$BASE/config,host-config,readonly=on,driver.type=virtiofs,accessmode=passthrough" \
  --filesystem "$BASE/secrets,host-secrets,readonly=on,driver.type=virtiofs,accessmode=passthrough" \
  --filesystem "$BASE/workspace,host-workspace,driver.type=virtiofs,accessmode=passthrough"

virsh snapshot-create-as "$VM_NAME" clean || true

echo ""
echo "Install finished. On first boot: ai-sandbox-virtiofs-mounts.service (~/ai-sandbox symlinks), then ai-sandbox-firstboot.service (install-inside-vm after network)."
echo "Username: ai"
