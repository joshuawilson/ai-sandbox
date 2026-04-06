#!/usr/bin/env bash
# macOS: stop UTM VM if utmctl is available; optional disk cleanup for repo vm/ disk.
set -euo pipefail

_HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/sandbox-root.sh
source "$_HS_HOST_DIR/lib/sandbox-root.sh"
BASE="$(sandbox_repo_root)"

VM_NAME="${UTM_VM_NAME:-ai-sandbox}"
DISK="$BASE/vm/${VM_NAME}.qcow2"
remove=false

for arg in "$@"; do
  case "$arg" in
    --remove | -r | --cleanup) remove=true ;;
    -h | --help)
      echo "Usage: $(basename "$0") [--remove]"
      echo "  Stops the UTM VM named like '$VM_NAME' if utmctl is installed (UTM 4+)."
      echo "  --remove  Delete $DISK (UTM machine entry is not removed automatically)."
      echo "  UTM_VM_NAME  Override VM display name to match (default: ai-sandbox)."
      echo ""
      echo "Without utmctl: stop the guest in the UTM window, then continue."
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

UTMCTL=""
if [[ -x "/Applications/UTM.app/Contents/MacOS/utmctl" ]]; then
  UTMCTL="/Applications/UTM.app/Contents/MacOS/utmctl"
elif command -v utmctl >/dev/null 2>&1; then
  UTMCTL="utmctl"
fi

if [[ -n "$UTMCTL" ]]; then
  # utmctl list: UUID name [state] — match VM name substring
  found=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    uuid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | cut -d' ' -f2-)
    if [[ "$name" == *"$VM_NAME"* ]] || [[ "$name" == "$VM_NAME" ]]; then
      echo "Stopping UTM VM: $name ($uuid)"
      "$UTMCTL" stop "$uuid" 2>/dev/null || "$UTMCTL" suspend "$uuid" 2>/dev/null || true
      found=1
      break
    fi
  done < <("$UTMCTL" list 2>/dev/null || true)
  if [[ -z "$found" ]]; then
    echo "No UTM VM listing matched '$VM_NAME'. Run: $UTMCTL list"
    echo "Stop the guest manually in UTM if it is running."
  fi
else
  echo "utmctl not found (install UTM 4+ or use UTM → Stop in the app)."
  open -a UTM 2>/dev/null || true
fi

if [[ "$remove" == true ]]; then
  if [[ -f "$DISK" ]]; then
    echo "Removing disk: $DISK"
    rm -f "$DISK"
  else
    echo "No disk at $DISK"
  fi
  echo "Remove the VM from UTM’s sidebar if you are reinstalling (UTM → Delete)."
fi
