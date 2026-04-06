#!/usr/bin/env bash
# Verify a macOS host is ready for create-vm-mac.sh (UTM + qemu tools from Homebrew).
# Run from Terminal. Does not modify the system.
set -u

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"

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

echo -e "${BOLD}=== AI Sandbox — macOS host check ===${NC}"
echo ""

if [[ "$(uname -s)" != "Darwin" ]]; then
  warn "This script is for macOS (Darwin). uname: $(uname -s)"
  warnings=$((warnings + 1))
else
  ok "Kernel: Darwin"
fi

# --- Apple Silicon vs x86_64 ISO (manual choice of image) ---
arch=$(uname -m)
if [[ "$arch" == "arm64" ]]; then
  warn "Apple Silicon ($arch): default scripts use x86_64 Fedora ISO — use an aarch64 image in UTM for native speed, or expect emulation."
  warnings=$((warnings + 1))
else
  ok "Machine arch: $arch (matches typical x86_64 ISO URLs in scripts)"
fi

# --- Homebrew ---
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew: $(command -v brew)"
else
  miss "Homebrew — install from https://brew.sh then run install-virt-mac.sh"
  issues=$((issues + 1))
fi

# --- Tools install-virt-mac.sh uses ---
for cmd in git curl jq; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "command: $cmd"
  else
    miss "command: $cmd — brew install $cmd (or run install-virt-mac.sh)"
    issues=$((issues + 1))
  fi
done

if command -v qemu-img >/dev/null 2>&1; then
  ok "command: qemu-img (qemu)"
else
  miss "qemu-img — brew install qemu"
  issues=$((issues + 1))
fi

# --- Python for tools/serve-kickstart.sh ---
if command -v python3 >/dev/null 2>&1; then
  ok "command: python3 (for tools/serve-kickstart.sh)"
else
  warn "python3 not found — install Xcode CLT or python.org; needed to serve ks.cfg over HTTP"
  warnings=$((warnings + 1))
fi

# --- UTM (manual install from website / App Store) ---
if [[ -d "/Applications/UTM.app" ]]; then
  ok "UTM.app found in /Applications"
else
  miss "UTM.app — install from https://mac.getutm.app/ (cannot be scripted here)"
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
  warn "no $BASE/secrets/ssh/id_ed25519.pub — run install-virt-mac.sh"
  warnings=$((warnings + 1))
fi

if [[ -f "$BASE/secrets/vm-password.env" ]]; then
  ok "secrets/vm-password.env present (for kickstart)"
else
  warn "no secrets/vm-password.env — create before generate-ks-mac.sh"
  warnings=$((warnings + 1))
fi

echo ""
echo -e "${BOLD}Manual steps (not scripted):${NC}"
echo "  • Grant UTM **Full Disk Access** or relevant privacy permissions if macOS blocks VM disk access (System Settings → Privacy)."
echo "  • Choose **Fedora aarch64** media on Apple Silicon if you do not want x86 emulation."
echo ""
echo -e "${BOLD}Summary:${NC}  issues=$issues  warnings=$warnings"
if [[ "$issues" -gt 0 ]]; then
  echo -e "${RED}Fix MISSING items before host/create-vm-mac.sh.${NC}"
  exit 1
fi
if [[ "$warnings" -gt 0 ]]; then
  echo -e "${YELLOW}Review WARN items.${NC}"
fi
if [[ "$warnings" -eq 0 ]]; then
  echo -e "${GREEN}Host looks ready to create the VM.${NC}"
else
  echo -e "${GREEN}Host is usable once WARN items are acceptable.${NC}"
fi
echo ""
echo -e "${BOLD}Next (first VM on this host):${NC}"
echo "  1. Ensure ${BASE}/secrets/vm-password.env exists (see host/write-vm-password-env.sh)."
echo "  2. Run:  host/create-vm-mac.sh"
echo ""
echo "That script runs generate-ks-mac.sh when secrets exist. Run generate-ks-mac.sh alone only to refresh ks.cfg without re-running the full create flow."
exit 0
