#!/usr/bin/env bash
set -e

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"
TEMPLATE="$BASE/host/ks.template.cfg"
OUTPUT="$BASE/ks.cfg"

echo "Generating Kickstart for macOS..."

# Load password
source "$BASE/secrets/vm-password.env"

if [ -z "$VM_PASSWORD" ]; then
  echo "VM_PASSWORD not set"
  exit 1
fi

echo "Generating hash..."
HASH=$(openssl passwd -6 "$VM_PASSWORD")

# Load SSH key
SSH_KEY=$(cat "$BASE/secrets/ssh/id_ed25519.pub")

OWNER_UID="$(stat -f %u "$BASE/secrets" 2>/dev/null || stat -c %u "$BASE/secrets" 2>/dev/null || true)"
if [[ -z "${OWNER_UID:-}" || "$OWNER_UID" == 0 ]]; then
  OWNER_UID="$(id -u)"
fi

echo "Injecting values..."

sed -e "s|__PASSWORD_HASH__|$HASH|g" \
    -e "s|__SSH_KEY__|$SSH_KEY|g" \
    -e "s|__SANDBOX_OWNER_UID__|$OWNER_UID|g" \
    "$TEMPLATE" > "$OUTPUT"

chmod 600 "$OUTPUT"

echo "ks.cfg generated successfully (macOS)"
