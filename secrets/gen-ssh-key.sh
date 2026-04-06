#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/secrets/ssh"
KEY="$ROOT/secrets/ssh/id_ed25519"
ssh-keygen -t ed25519 -f "$KEY" -N ""
echo "Public key:"
cat "$KEY.pub"
