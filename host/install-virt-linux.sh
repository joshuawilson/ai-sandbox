#!/bin/bash
set -e

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"

echo "Creating sandbox directories..."
mkdir -p "$BASE/config" "$BASE/secrets/ssh" "$BASE/workspace" "$BASE/logs"

# Flatten legacy workspace/projects/<name> -> workspace/<name>
if [[ -d "$BASE/workspace/projects" ]]; then
  shopt -s nullglob
  for item in "$BASE/workspace/projects"/*; do
    [[ -e "$item" ]] || continue
    base=$(basename "$item")
    if [[ -e "$BASE/workspace/$base" ]]; then
      echo "Skipping migrate workspace/projects/$base: workspace/$base exists" >&2
      continue
    fi
    mv "$item" "$BASE/workspace/$base"
  done
  shopt -u nullglob
  rmdir "$BASE/workspace/projects" 2>/dev/null || true
fi

# Legacy top-level ~/ai-sandbox/projects -> workspace/
if [[ -d "$BASE/projects" ]] && [[ ! -L "$BASE/projects" ]]; then
  echo "Moving $BASE/projects -> workspace/ (if any files)..."
  if [[ -n "$(ls -A "$BASE/projects" 2>/dev/null)" ]]; then
    shopt -s nullglob
    for item in "$BASE/projects"/*; do
      [[ -e "$item" ]] || continue
      base=$(basename "$item")
      if [[ ! -e "$BASE/workspace/$base" ]]; then
        cp -a "$item" "$BASE/workspace/$base" || true
      fi
    done
    shopt -u nullglob
  fi
  rm -rf "$BASE/projects"
fi

echo "Installing virtualization stack..."
# acl: setfacl for qemu virtiofs from $HOME. policycoreutils-python-utils: semanage/restorecon for virt_content_t.
sudo dnf install -y \
    @virtualization \
    qemu-kvm \
    libvirt \
    virt-install \
    virt-manager \
    git \
    curl \
    jq \
    bridge-utils \
    acl \
    policycoreutils-python-utils

sudo systemctl enable --now libvirtd

sudo usermod -aG libvirt $USER

echo "Generating sandbox SSH key..."
KEY="$BASE/secrets/ssh/id_ed25519"

if [ ! -f "$KEY" ]; then
  echo "Generating SSH key for sandbox..."

  ssh-keygen -t ed25519 -f "$KEY" -N ""

  echo ""
  echo "Add this key to GitHub/GitLab:"
  echo ""

  cat "$KEY.pub"
fi

chmod 700 "$BASE/secrets" "$BASE/secrets/ssh" 2>/dev/null || true
find "$BASE/secrets" -type f -exec chmod 600 {} \; 2>/dev/null || true

# Libvirt runs QEMU as user qemu; repos under /home are not readable without ACLs + virt_content_t (SELinux).
# Do this here so a fresh clone under $HOME works before the first create-vm-linux.sh.
# shellcheck source=lib/virtiofs-qemu-access.sh
source "$_HS_HOST_DIR/lib/virtiofs-qemu-access.sh"
echo ""
echo "Preparing virtiofs access for libvirt QEMU (ACLs + SELinux; needed when repo is under /home)..."
ensure_qemu_access_for_virtiofs "$BASE" || {
  echo "virtiofs preparation failed. Fix packages (acl, policycoreutils-python-utils), then run:" >&2
  echo "  ./host/fix-virtiofs-qemu-access.sh" >&2
  exit 1
}

echo ""
echo "Linux host setup complete."
echo "Log out and back in for the libvirt group, then run:  ./setup-host.sh --check-only"
echo "(same as host/check-host-fedora.sh)"