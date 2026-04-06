# shellcheck shell=bash
# Sync guest Claude files into the per-container dir that becomes /home/dev in Podman (so claude inside
# the container sees the same settings, ~/.claude.json MCP merge, and skills as on the VM).
# Usage after defining DEV_HOME_DIR and SANDBOX (repo root):
#   source .../podman-claude-devhome.sh
#   ai_sandbox_sync_claude_settings_to_dev_home "$DEV_HOME_DIR" "$SANDBOX"
#   ai_sandbox_sync_claude_userdata_to_dev_home "$DEV_HOME_DIR"

ai_sandbox_sync_claude_settings_to_dev_home() {
  local dev_home="${1:?}"
  local sandbox="${2:?}"
  local guest="$HOME/.claude/settings.json"
  local tmpl="$sandbox/config/claude-code.settings.json"

  mkdir -p "$dev_home/.claude"
  if [[ -f "$guest" && -s "$guest" ]]; then
    install -m 600 "$guest" "$dev_home/.claude/settings.json"
  elif [[ -f "$tmpl" ]]; then
    install -m 600 "$tmpl" "$dev_home/.claude/settings.json"
  else
    echo "ai-sandbox: warning: no Claude settings (guest $guest and template $tmpl missing)" >&2
  fi
}

ai_sandbox_sync_claude_userdata_to_dev_home() {
  local dev_home="${1:?}"
  mkdir -p "$dev_home/.claude"
  if [[ -f "$HOME/.claude.json" && -s "$HOME/.claude.json" ]]; then
    install -m 600 "$HOME/.claude.json" "$dev_home/.claude.json"
  fi
  if [[ -d "$HOME/.claude/skills" ]]; then
    mkdir -p "$dev_home/.claude/skills"
    cp -a "$HOME/.claude/skills"/. "$dev_home/.claude/skills"/
  fi
}
