#!/usr/bin/env bash
# Shared by install-inside-vm.sh and setup-claude.sh — idempotent shell login hook for Vertex / Claude env.
# shellcheck shell=bash

readonly AI_SANDBOX_CLAUDE_LOGIN_MARKER='# ai-sandbox: Claude Code env (claude-vertex.env)'

# Usage: ai_sandbox_install_claude_login_hook ~/.bashrc
ai_sandbox_install_claude_login_hook() {
  local rc_path="${1:-}"
  [[ -n "$rc_path" ]] || return 1
  [[ -f "$rc_path" ]] || touch "$rc_path"
  if grep -qF "$AI_SANDBOX_CLAUDE_LOGIN_MARKER" "$rc_path" 2>/dev/null; then
    return 0
  fi
  cat >> "$rc_path" <<'EOF'

# ai-sandbox: Claude Code env (claude-vertex.env)
if [[ -f ~/.config/ai-sandbox/claude-vertex.env ]]; then
  # shellcheck disable=SC1090
  . ~/.config/ai-sandbox/claude-vertex.env
fi
EOF
}

# Copy host-backed Vertex env into the guest home.
# Tries secrets/claude-vertex.env first, then workspace/.ai-sandbox-private/claude-vertex.env
# (writable from the guest when secrets virtiofs is read-only).
# Usage: ai_sandbox_sync_claude_vertex_env_from_sandbox ~/ai-sandbox
ai_sandbox_sync_claude_vertex_env_from_sandbox() {
  local sandbox="${1:-}"
  [[ -n "$sandbox" ]] || return 1
  local src=""
  if [[ -r "$sandbox/secrets/claude-vertex.env" ]]; then
    src="$sandbox/secrets/claude-vertex.env"
  elif [[ -r "$sandbox/workspace/.ai-sandbox-private/claude-vertex.env" ]]; then
    src="$sandbox/workspace/.ai-sandbox-private/claude-vertex.env"
  fi
  if [[ -z "$src" ]]; then
    return 0
  fi
  mkdir -p "$HOME/.config/ai-sandbox"
  install -m 600 "$src" "$HOME/.config/ai-sandbox/claude-vertex.env"
}

# Backward-compatible name
ai_sandbox_sync_claude_vertex_env_from_secrets() {
  ai_sandbox_sync_claude_vertex_env_from_sandbox "$1"
}
