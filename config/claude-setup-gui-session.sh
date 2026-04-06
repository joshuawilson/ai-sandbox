#!/usr/bin/env bash
# Runs inside gnome-terminal from run-claude-setup-once.sh (graphical first-login path).
set -euo pipefail

if [[ -z "${SANDBOX:-}" ]] && [[ -r "$HOME/.config/ai-sandbox/sandbox-root" ]]; then
  SANDBOX="$(head -n1 "$HOME/.config/ai-sandbox/sandbox-root" | tr -d '\r')"
fi
SANDBOX="${SANDBOX:-$HOME/ai-sandbox}"
export AI_SANDBOX_SETUP_FROM_INSTALL=1
bash "$SANDBOX/config/setup-claude.sh" || true

mkdir -p ~/.config/ai-sandbox
touch ~/.config/ai-sandbox/claude-setup-autorun.done
rm -f ~/.config/autostart/ai-sandbox-claude-setup.desktop

read -r -p "Press Enter to close this window..." _ || true
