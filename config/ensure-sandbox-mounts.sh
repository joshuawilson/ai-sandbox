#!/bin/bash
# Idempotent: virtiofs (libvirt Linux) OR SMB/CIFS (Hyper-V, UTM, or any host share) + ~/ai-sandbox symlinks. Run with sudo.
set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-ai}}"
SANDBOX_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SANDBOX="$SANDBOX_HOME/ai-sandbox"

mkdir -p /mnt/host-config /mnt/host-secrets /mnt/host-workspace /mnt/host-ai-sandbox

USE_CIFS=0
if [[ -f /etc/ai-sandbox/cifs.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /etc/ai-sandbox/cifs.env
  set +a
  [[ "${USE_CIFS:-0}" == "1" ]] && USE_CIFS=1
fi

mount_cifs_tree() {
  [[ -n "${CIFS_URL:-}" ]] || {
    echo "USE_CIFS=1 but CIFS_URL missing in /etc/ai-sandbox/cifs.env" >&2
    return 1
  }
  local cred="${CIFS_CREDENTIALS:-/etc/ai-sandbox/smbcredentials}"
  [[ -f "$cred" ]] || {
    echo "Missing SMB credentials file: $cred (see config/cifs.env.example)" >&2
    return 1
  }
  if ! command -v mount.cifs >/dev/null 2>&1; then
    dnf install -y cifs-utils
  fi
  local uid gid
  uid=$(id -u "$TARGET_USER")
  gid=$(id -g "$TARGET_USER")
  if ! mountpoint -q /mnt/host-ai-sandbox 2>/dev/null; then
    mount -t cifs "$CIFS_URL" /mnt/host-ai-sandbox -o "credentials=$cred,uid=$uid,gid=$gid,file_mode=0644,dir_mode=0755,noperm"
  fi
  mkdir -p "/mnt/host-ai-sandbox/config" "/mnt/host-ai-sandbox/secrets" "/mnt/host-ai-sandbox/workspace" 2>/dev/null || true
  if ! mountpoint -q /mnt/host-config 2>/dev/null; then
    mount --bind "/mnt/host-ai-sandbox/config" /mnt/host-config
  fi
  if ! mountpoint -q /mnt/host-secrets 2>/dev/null; then
    mount --bind "/mnt/host-ai-sandbox/secrets" /mnt/host-secrets
  fi
  if ! mountpoint -q /mnt/host-workspace 2>/dev/null; then
    mount --bind "/mnt/host-ai-sandbox/workspace" /mnt/host-workspace
  fi
}

mount_virtiofs_tree() {
  if ! mountpoint -q /mnt/host-config 2>/dev/null; then
    mount -t virtiofs host-config /mnt/host-config
  fi
  if ! mountpoint -q /mnt/host-secrets 2>/dev/null; then
    mount -t virtiofs host-secrets /mnt/host-secrets -o ro
  fi
  if ! mountpoint -q /mnt/host-workspace 2>/dev/null; then
    mount -t virtiofs host-workspace /mnt/host-workspace
  fi
}

if [[ "$USE_CIFS" == "1" ]]; then
  mount_cifs_tree
  echo "CIFS mode: persist mounts across reboots with /etc/fstab entries (see config/cifs.env.example)." >&2
else
  mount_virtiofs_tree
  if ! grep -q '# ai-sandbox virtiofs' /etc/fstab 2>/dev/null; then
    {
      echo "# ai-sandbox virtiofs"
      echo "host-config    /mnt/host-config     virtiofs    defaults,ro    0 0"
      echo "host-secrets   /mnt/host-secrets    virtiofs    defaults,ro    0 0"
      echo "host-workspace /mnt/host-workspace  virtiofs    defaults       0 0"
    } >> /etc/fstab
  fi
fi

WS=/mnt/host-workspace
install -d -o "$TARGET_USER" -g "$TARGET_USER" "$WS"

# Flatten legacy workspace/projects/<name> → workspace/<name>; then remove empty projects/.
migrate_legacy_workspace_projects_dir() {
  if [[ ! -d "$WS/projects" ]]; then
    return 0
  fi
  shopt -s nullglob
  local item base dest
  for item in "$WS/projects"/*; do
    [[ -e "$item" ]] || continue
    base=$(basename "$item")
    dest="$WS/$base"
    if [[ -e "$dest" ]]; then
      echo "ai-sandbox: skip migrate workspace/projects/$base — $dest already exists" >&2
      continue
    fi
    mv "$item" "$dest"
  done
  shopt -u nullglob
  rmdir "$WS/projects" 2>/dev/null || true
}

migrate_legacy_workspace_projects_dir

# Guest-local ~/ai-sandbox/projects (real directory from old layouts) → workspace root on host share.
if [[ -e "$SANDBOX/projects" && ! -L "$SANDBOX/projects" ]]; then
  echo "Migrating $SANDBOX/projects (guest directory) into host workspace/ ..." >&2
  if [[ -d "$SANDBOX/projects" ]] && [[ -n "$(ls -A "$SANDBOX/projects" 2>/dev/null)" ]]; then
    shopt -s nullglob
    for item in "$SANDBOX/projects"/*; do
      [[ -e "$item" ]] || continue
      base=$(basename "$item")
      dest="$WS/$base"
      if [[ -e "$dest" ]]; then
        echo "ai-sandbox: skip migrate ~/projects/$base — exists in workspace" >&2
        continue
      fi
      cp -a "$item" "$dest" || true
    done
    shopt -u nullglob
  fi
  rm -rf "$SANDBOX/projects"
fi

# Obsolete symlink ~/ai-sandbox/projects → …/projects (replaced by workspace/<name>).
if [[ -L "$SANDBOX/projects" ]]; then
  rm -f "$SANDBOX/projects"
fi

install -d -o "$TARGET_USER" -g "$TARGET_USER" "$SANDBOX" "$SANDBOX/logs"

ln -sfn /mnt/host-config "$SANDBOX/config"
ln -sfn /mnt/host-secrets "$SANDBOX/secrets"
ln -sfn /mnt/host-workspace "$SANDBOX/workspace"

chown -h "$TARGET_USER:$TARGET_USER" "$SANDBOX/config" "$SANDBOX/secrets" "$SANDBOX/workspace" 2>/dev/null || true
