#!/usr/bin/env bash
set -e

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"
TEMPLATE="$BASE/host/ks.template.cfg"
OUTPUT="$BASE/ks.cfg"

echo "Generating password hash..."

source "$BASE/secrets/vm-password.env"

HASH=$(openssl passwd -6 "$VM_PASSWORD")

echo "Injecting into ks.cfg..."

SANDBOX_KEY="$BASE/secrets/ssh/id_ed25519.pub"
if [ ! -f "$SANDBOX_KEY" ]; then
  echo "Missing sandbox SSH public key: $SANDBOX_KEY" >&2
  echo "Run install-virt-linux.sh (or secrets/gen-ssh-key.sh) to generate it." >&2
  exit 1
fi

SSH_KEY=$(cat "$SANDBOX_KEY")

# Guest ai must use the same UID as the host checkout's secrets/ owner, or virtiofs mode-700 dirs deny access.
OWNER_UID="$(stat -c %u "$BASE/secrets" 2>/dev/null || true)"
if [[ -z "${OWNER_UID:-}" || "$OWNER_UID" == 0 ]]; then
  OWNER_UID="$(id -u)"
fi

sed -e "s|__PASSWORD_HASH__|$HASH|g" \
    -e "s|__SSH_KEY__|$SSH_KEY|g" \
    -e "s|__SANDBOX_OWNER_UID__|$OWNER_UID|g" \
    "$TEMPLATE" > "$OUTPUT"

chmod 600 "$OUTPUT"

echo "ks.cfg generated successfully (guest user ai uid=$OWNER_UID — matches owner of $BASE/secrets)."
