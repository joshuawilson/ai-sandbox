#!/usr/bin/env bash
# XDG autostart entrypoint: open a real terminal with a TTY for setup-claude.sh (first GNOME login after non-interactive install).
set -euo pipefail

# Written by install-inside-vm.sh when registering GNOME autostart (path may differ from ~/ai-sandbox).
if [[ -z "${SANDBOX:-}" ]] && [[ -r "$HOME/.config/ai-sandbox/sandbox-root" ]]; then
  SANDBOX="$(head -n1 "$HOME/.config/ai-sandbox/sandbox-root" | tr -d '\r')"
fi
SANDBOX="${SANDBOX:-$HOME/ai-sandbox}"

[[ "${AI_SANDBOX_SKIP_CLAUDE_SETUP:-}" == "1" ]] && exit 0
[[ -f "$HOME/.config/ai-sandbox/claude-setup-autorun.done" ]] && exit 0
[[ -z "${DISPLAY:-}" ]] && exit 0

if ! command -v gnome-terminal >/dev/null 2>&1; then
  exit 0
fi

exec gnome-terminal --wait --title="AI Sandbox — Claude setup" -- bash "$SANDBOX/config/claude-setup-gui-session.sh"
