#!/usr/bin/env bash
# Copy host-backed secrets/claude-vertex.env or workspace/.ai-sandbox-private/claude-vertex.env
# into ~/.config/ai-sandbox/claude-vertex.env on the guest. Run inside the VM after editing the host file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="${1:-$HOME/ai-sandbox}"
SANDBOX="$(cd "$SANDBOX" 2>/dev/null && pwd || true)"
[[ -n "$SANDBOX" && -d "$SANDBOX" ]] || {
  echo "usage: $0 [path-to-ai-sandbox-repo]" >&2
  exit 1
}

if [[ ! -r "$SANDBOX/secrets/claude-vertex.env" && ! -r "$SANDBOX/workspace/.ai-sandbox-private/claude-vertex.env" ]]; then
  echo "No readable claude-vertex.env under $SANDBOX/secrets/ or $SANDBOX/workspace/.ai-sandbox-private/" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/claude-login-env.sh"

ai_sandbox_sync_claude_vertex_env_from_sandbox "$SANDBOX"
echo "Updated $HOME/.config/ai-sandbox/claude-vertex.env"
