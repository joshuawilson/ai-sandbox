# shellcheck shell=bash
# libvirt runs QEMU as user "qemu" with SELinux types (e.g. svirt_t) that cannot read
# user_home_t paths under /home/... even when DAC/ACL allows "qemu" — you need virt_content_t.
#
# Usage: source this file, then: ensure_qemu_access_for_virtiofs "$BASE"
# Set SKIP_VIRTIOFS_QEMU_ACL=1 to skip (you must fix DAC + SELinux yourself).
#
# Order matters: apply SELinux labels *before* sudo -u qemu tests. With Enforcing, user_home_t
# can deny the qemu user even when setfacl granted rX; virt_content_t fixes that for checks and
# for libvirt's QEMU (svirt_t).

ensure_qemu_access_for_virtiofs() {
  local base="$1"
  if [[ "${SKIP_VIRTIOFS_QEMU_ACL:-}" == "1" ]]; then
    return 0
  fi
  if ! id qemu &>/dev/null; then
    echo "virtiofs-qemu-access: no user 'qemu' on this system; skipping check." >&2
    return 0
  fi
  if ! command -v setfacl >/dev/null 2>&1; then
    echo "virtiofs-qemu-access: setfacl not found. Install: sudo dnf install acl" >&2
    return 1
  fi

  # --- DAC: ACLs so user qemu can traverse /home/... and use the three virtiofs trees ---
  echo "virtiofs: Applying ACLs so user qemu can access $base/{config,secrets,workspace}..." >&2

  local d="$base"
  while [[ "$d" != "/" ]]; do
    sudo setfacl -m u:qemu:rx "$d" || {
      echo "setfacl failed on $d" >&2
      return 1
    }
    local nd
    nd=$(dirname "$d")
    [[ "$d" == "$nd" ]] && break
    d="$nd"
  done

  if ! sudo setfacl -R -m u:qemu:rX "$base/config" "$base/secrets"; then
    echo "virtiofs: setfacl -R on config/secrets failed (is the filesystem mounted with ACL support? e.g. ext4 defaults)." >&2
    return 1
  fi
  if ! sudo setfacl -R -m u:qemu:rwX "$base/workspace"; then
    echo "virtiofs: setfacl -R on workspace failed." >&2
    return 1
  fi

  # --- SELinux before access tests: Enforcing may block qemu on user_home_t despite ACLs ---
  if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
    echo "virtiofs: Setting SELinux type virt_content_t on config, secrets, workspace..." >&2
    if command -v semanage >/dev/null 2>&1; then
      sudo semanage fcontext -a -t virt_content_t "${base}(/.*)?" 2>/dev/null || true
      sudo restorecon -RFv "$base/config" "$base/secrets" "$base/workspace" 2>/dev/null || true
    else
      echo "virtiofs: install policycoreutils-python-utils for persistent SELinux labels (semanage)." >&2
      sudo chcon -Rt virt_content_t "$base/config" "$base/secrets" "$base/workspace" 2>/dev/null || {
        echo "virtiofs: chcon failed. Install: sudo dnf install policycoreutils-python-utils" >&2
        return 1
      }
    fi
  fi

  # --- Verify qemu can open the same paths libvirt will use for virtiofs ---
  if ! sudo -u qemu test -r "$base/config" 2>/dev/null; then
    echo "virtiofs: still cannot read $base/config as qemu (check DAC ACLs and SELinux labels)." >&2
    echo "  Try:  getenforce  ls -Z $base/secrets  sudo -u qemu ls $base/secrets" >&2
    return 1
  fi
  if ! sudo -u qemu test -r "$base/secrets" 2>/dev/null \
    || ! sudo -u qemu test -x "$base/secrets" 2>/dev/null; then
    echo "virtiofs: still cannot access $base/secrets as qemu." >&2
    echo "  secrets/ is often mode 700; needs ACL user:qemu and (if Enforcing) virt_content_t on the tree." >&2
    return 1
  fi
  if ! sudo -u qemu test -r "$base/workspace" 2>/dev/null \
    || ! sudo -u qemu test -x "$base/workspace" 2>/dev/null; then
    echo "virtiofs: still cannot access $base/workspace as qemu." >&2
    return 1
  fi

  echo "virtiofs: paths prepared for $base (DAC + SELinux when applicable)." >&2
  return 0
}
