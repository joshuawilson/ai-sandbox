#!/usr/bin/env bash
# XDG autostart entrypoint: open a real terminal with a TTY for setup-claude.sh (first desktop login after non-interactive install).
set -euo pipefail

# Written by install-inside-vm.sh when registering GNOME autostart (path may differ from ~/ai-sandbox).
if [[ -z "${SANDBOX:-}" ]] && [[ -r "$HOME/.config/ai-sandbox/sandbox-root" ]]; then
  SANDBOX="$(head -n1 "$HOME/.config/ai-sandbox/sandbox-root" | tr -d '\r')"
fi
SANDBOX="${SANDBOX:-$HOME/ai-sandbox}"

[[ "${AI_SANDBOX_SKIP_CLAUDE_SETUP:-}" == "1" ]] && exit 0
[[ -f "$HOME/.config/ai-sandbox/claude-setup-autorun.done" ]] && exit 0
[[ -z "${DISPLAY:-}" ]] && exit 0

# Open in whatever terminal the session provides: gnome-terminal (GNOME),
# xfce4-terminal (XFCE Enhanced Session over xrdp), or terminator (installed by kickstart).
title="AI Sandbox — Claude setup"
session_script="$SANDBOX/config/claude-setup-gui-session.sh"
if command -v gnome-terminal >/dev/null 2>&1; then
  exec gnome-terminal --wait --title="$title" -- bash "$session_script"
elif command -v xfce4-terminal >/dev/null 2>&1; then
  exec xfce4-terminal --disable-server --title="$title" --command="bash $session_script"
elif command -v terminator >/dev/null 2>&1; then
  exec terminator --title="$title" -x bash "$session_script"
else
  exit 0
fi
