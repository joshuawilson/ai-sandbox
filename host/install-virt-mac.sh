#!/usr/bin/env bash
set -e

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"

mkdir -p "$BASE/config" "$BASE/secrets/ssh" "$BASE/workspace" "$BASE/logs"
if [[ -d "$BASE/workspace/projects" ]]; then
  shopt -s nullglob
  for item in "$BASE/workspace/projects"/*; do
    [[ -e "$item" ]] || continue
    base=$(basename "$item")
    [[ -e "$BASE/workspace/$base" ]] && continue
    mv "$item" "$BASE/workspace/$base"
  done
  shopt -u nullglob
  rmdir "$BASE/workspace/projects" 2>/dev/null || true
fi
if [[ -d "$BASE/projects" ]] && [[ ! -L "$BASE/projects" ]]; then
  if [[ -n "$(ls -A "$BASE/projects" 2>/dev/null)" ]]; then
    shopt -s nullglob
    for item in "$BASE/projects"/*; do
      [[ -e "$item" ]] || continue
      base=$(basename "$item")
      [[ -e "$BASE/workspace/$base" ]] || cp -a "$item" "$BASE/workspace/$base" || true
    done
    shopt -u nullglob
  fi
  rm -rf "$BASE/projects"
fi

echo "Installing dependencies with Homebrew..."

if ! command -v brew >/dev/null; then
  echo "Install Homebrew first: https://brew.sh"
  exit 1
fi

brew install qemu git curl jq

echo "Generate sandbox SSH key..."

KEY="$BASE/secrets/ssh/id_ed25519"

if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -f "$KEY" -N ""
fi

chmod -R 700 "$BASE/secrets"

echo ""
echo "Install UTM from:"
echo "https://mac.getutm.app/"
echo ""
echo "Then run:  ./setup-host.sh --check-only"
echo "(same as host/check-host-mac.sh)"
