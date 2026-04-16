#!/usr/bin/env bash
# macOS: UTM has no stable one-shot CLI for "start this VM" in all setups — open UTM and start/resume manually.
set -euo pipefail

echo "Open UTM and start or resume your Fedora sandbox VM."
echo "Then in the guest:  ~/ai-sandbox/config/start-dev.sh"
if [[ -d "/Applications/UTM.app" ]]; then
  open -a UTM 2>/dev/null || true
fi
