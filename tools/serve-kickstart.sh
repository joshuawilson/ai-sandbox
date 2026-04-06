#!/usr/bin/env bash
# Serve the ai-sandbox repo root over HTTP so the Fedora installer can use inst.ks=http://<host>:PORT/ks.cfg
set -euo pipefail
_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${SANDBOX:-${AI_SANDBOX_HOME:-$(cd "$_TOOLS_DIR/.." && pwd)}}"
PORT="${PORT:-8000}"
cd "$BASE"
if [[ ! -f ks.cfg ]]; then
  echo "Missing $BASE/ks.cfg — run host/generate-ks-fedora.sh, host/generate-ks-mac.sh, or host/generate-ks-windows.ps1 first." >&2
  exit 1
fi
echo "Serving directory: $BASE"
echo "Kickstart URL (use your host LAN IP):  http://<host-ip>:$PORT/ks.cfg"
echo "At the Anaconda boot screen, edit boot options and append:"
echo "  inst.ks=http://<host-ip>:$PORT/ks.cfg"
echo "Or use the same URL in a netinstall if prompted."
echo "Stop with Ctrl+C. (Allow TCP $PORT through the host firewall if needed.)"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
