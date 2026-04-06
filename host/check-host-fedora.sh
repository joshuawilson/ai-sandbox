#!/usr/bin/env bash
# Verify a Fedora host is ready for create-vm-linux.sh (KVM + libvirt system session).
# Run from your user account (not root). Does not modify the system.
set -u

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"
URI="qemu:///system"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ok() { echo -e "${GREEN}OK${NC}  $*"; }
warn() { echo -e "${YELLOW}WARN${NC} $*"; }
miss() { echo -e "${RED}MISS${NC} $*"; }

issues=0
warnings=0

echo -e "${BOLD}=== AI Sandbox — Fedora host check ===${NC}"
echo "Using libvirt URI: $URI (system session — do not mix with qemu:///session for these VMs)"
echo ""

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" == "fedora" ]]; then
    ok "OS: Fedora ${VERSION_ID:-?}"
  else
    warn "Not Fedora (ID=${ID:-unknown}). This checklist targets Fedora + dnf."
    warnings=$((warnings + 1))
  fi
else
  warn "/etc/os-release missing"
  warnings=$((warnings + 1))
fi

# --- BIOS / CPU: cannot enable from script ---
if [[ -r /proc/cpuinfo ]] && grep -qE '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
  ok "CPU reports virtualization flags (vmx or svm)"
else
  warn "No vmx/svm in /proc/cpuinfo — enable VT-x/AMD-V (or SVM) in firmware (see README)."
  warnings=$((warnings + 1))
fi

if [[ -e /dev/kvm ]]; then
  ok "/dev/kvm exists (KVM usable)"
else
  miss "/dev/kvm missing — enable virtualization in BIOS; load kvm module: sudo modprobe kvm_intel or kvm_amd"
  issues=$((issues + 1))
fi

if [[ -r /dev/kvm ]] && ! groups | grep -qE '\bkvm\b'; then
  warn "User not in group kvm (optional on some setups). If VM start fails: sudo usermod -aG kvm $USER && re-login"
  warnings=$((warnings + 1))
fi

# --- Packages (@virtualization group) ---
if command -v rpm >/dev/null 2>&1; then
  if rpm -q libvirt &>/dev/null || rpm -q libvirt-daemon-kvm &>/dev/null; then
    ok "libvirt (rpm)"
  else
    miss "libvirt — run: sudo dnf install @virtualization"
    issues=$((issues + 1))
  fi
  if rpm -q qemu-kvm &>/dev/null || rpm -q qemu-system-x86 &>/dev/null; then
    ok "qemu-kvm (rpm)"
  else
    miss "qemu-kvm — sudo dnf install @virtualization"
    issues=$((issues + 1))
  fi
  if rpm -q virt-install &>/dev/null; then ok "virt-install (rpm)"; else miss "virt-install — sudo dnf install @virtualization"; issues=$((issues + 1)); fi
else
  warn "rpm not found; skipping package name checks"
  warnings=$((warnings + 1))
fi

for cmd in virsh virt-install; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "command: $cmd"
  else
    miss "command: $cmd — install @virtualization"
    issues=$((issues + 1))
  fi
done

# --- virtiofs from $HOME (host/create-vm-linux.sh): DAC + SELinux ---
if rpm -q acl &>/dev/null; then
  ok "acl (rpm) — setfacl for qemu"
else
  warn "acl missing — virtiofs from ~/ needs setfacl: sudo dnf install acl"
  warnings=$((warnings + 1))
fi
if rpm -q policycoreutils-python-utils &>/dev/null; then
  ok "policycoreutils-python-utils (semanage) — SELinux labels for virtiofs"
else
  warn "policycoreutils-python-utils missing — virtiofs under /home needs semanage: sudo dnf install policycoreutils-python-utils"
  warnings=$((warnings + 1))
fi

# --- libvirtd (system daemon) ---
if systemctl is-enabled libvirtd &>/dev/null || systemctl is-active libvirtd &>/dev/null; then
  if systemctl is-active --quiet libvirtd 2>/dev/null; then
    ok "libvirtd is running"
  else
    miss "libvirtd not running — sudo systemctl enable --now libvirtd"
    issues=$((issues + 1))
  fi
else
  miss "libvirtd not installed/enabled — sudo systemctl enable --now libvirtd"
  issues=$((issues + 1))
fi

# --- User in libvirt (avoid permission errors with qemu:///system) ---
if id -nG "$USER" | tr ' ' '\n' | grep -qx libvirt; then
  ok "user $USER is in group libvirt"
else
  miss "user not in libvirt — sudo usermod -aG libvirt $USER  then log out and back in"
  issues=$((issues + 1))
fi

# --- Always use system URI for virsh (avoids session vs system mix-ups) ---
if ! virsh -c "$URI" uri &>/dev/null; then
  miss "cannot connect to $URI — fix libvirtd and group membership"
  issues=$((issues + 1))
else
  ok "virsh -c $URI connects"
fi

# --- Default NAT network (virt-install uses network=default) ---
if virsh -c "$URI" net-info default &>/dev/null; then
  active=$(virsh -c "$URI" net-info default 2>/dev/null | sed -n 's/^Active:[[:space:]]*//p' | tr -d '[:space:]')
  autostart=$(virsh -c "$URI" net-info default 2>/dev/null | sed -n 's/^Autostart:[[:space:]]*//p' | tr -d '[:space:]')
  if [[ "${active:-}" == "yes" ]]; then
    ok "libvirt network 'default' is active (NAT, usually virbr0)"
  else
    miss "network 'default' exists but inactive — sudo virsh -c $URI net-start default"
    issues=$((issues + 1))
  fi
  if [[ "${autostart:-}" == "yes" ]]; then
    ok "network 'default' autostarts"
  else
    miss "network 'default' not autostarting — sudo virsh -c $URI net-autostart default"
    issues=$((issues + 1))
  fi
else
  miss "network 'default' missing — sudo virsh -c $URI net-list --all && net-define /usr/share/libvirt/networks/default.xml (if needed)"
  issues=$((issues + 1))
fi

# --- Repo layout ---
if [[ -d "$BASE" ]]; then
  ok "directory $BASE exists"
else
  warn "clone this repo to $BASE"
  warnings=$((warnings + 1))
fi

if [[ -f "$BASE/secrets/ssh/id_ed25519.pub" ]]; then
  ok "sandbox SSH public key present"
else
  warn "no $BASE/secrets/ssh/id_ed25519.pub — run install-virt-linux.sh"
  warnings=$((warnings + 1))
fi

if [[ -f "$BASE/secrets/vm-password.env" ]]; then
  ok "secrets/vm-password.env present (for kickstart)"
else
  warn "no secrets/vm-password.env — create before generate-ks-fedora.sh"
  warnings=$((warnings + 1))
fi

# --- virtiofs: QEMU must access config/, secrets/, workspace/ (clone under /home needs ACL + virt_content_t) ---
if id qemu &>/dev/null && [[ -f "$BASE/config/ensure-sandbox-mounts.sh" ]]; then
  if sudo -u qemu test -r "$BASE/config/ensure-sandbox-mounts.sh" \
    && sudo -u qemu test -r "$BASE/secrets" \
    && sudo -u qemu test -x "$BASE/secrets" \
    && sudo -u qemu test -r "$BASE/workspace" \
    && sudo -u qemu test -x "$BASE/workspace"; then
    ok "QEMU can access $BASE/{config,secrets,workspace} (virtiofs will work in the guest)"
  else
    # sudo -u qemu can fail under some sudoers (requiretty, !u) even when ACLs are correct.
    qemu_acl_ok=true
    if command -v getfacl &>/dev/null; then
      for p in "$BASE" "$BASE/config" "$BASE/secrets" "$BASE/workspace"; do
        if ! getfacl -c "$p" 2>/dev/null | grep -q '^user:qemu:'; then
          qemu_acl_ok=false
          break
        fi
      done
    else
      qemu_acl_ok=false
    fi
    if [[ "$qemu_acl_ok" == true ]]; then
      warn "user:qemu ACLs are present but 'sudo -u qemu test' failed (sudo policy or password?). virtiofs may still work; verify:  sudo -u qemu test -r \"$BASE/secrets\" && sudo -u qemu test -x \"$BASE/secrets\""
      warnings=$((warnings + 1))
    else
      miss "QEMU cannot access config/secrets/workspace — run:  ./host/fix-virtiofs-qemu-access.sh"
      echo "  (needs sudo). If setfacl errors mention 'Operation not supported', remount with ACL: mount -o remount,acl /home" >&2
      issues=$((issues + 1))
    fi
  fi
elif ! id qemu &>/dev/null; then
  warn "user qemu not found (unusual) — skipping virtiofs QEMU read check"
  warnings=$((warnings + 1))
fi

echo ""
echo -e "${BOLD}Summary:${NC}  issues=$issues  warnings=$warnings"
if [[ "$issues" -gt 0 ]]; then
  echo -e "${RED}Fix MISSING items before host/create-vm-linux.sh.${NC}"
  exit 1
fi
if [[ "$warnings" -gt 0 ]]; then
  echo -e "${YELLOW}Review WARN items; you may still proceed.${NC}"
fi
if [[ "$warnings" -eq 0 ]]; then
  echo -e "${GREEN}Host looks ready to create the VM.${NC}"
else
  echo -e "${GREEN}Host is usable once WARN items are acceptable.${NC}"
fi
echo ""
echo -e "${BOLD}Next (first VM on this host):${NC}"
echo "  1. Ensure ${BASE}/secrets/vm-password.env exists (see host/write-vm-password-env.sh)."
echo "  2. Run:  host/create-vm-linux.sh"
echo ""
echo "That script runs generate-ks-fedora.sh for you, then virt-install. You do not pick between"
echo "two scripts: only run host/generate-ks-fedora.sh alone if you want to refresh ks.cfg without reinstalling."
exit 0
