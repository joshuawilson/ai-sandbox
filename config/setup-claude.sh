#!/usr/bin/env bash
# Interactive Claude Code setup: Red Hat (Vertex + gcloud) vs Anthropic (standard API / install.sh).
# Run on the machine where you use Claude (Fedora VM guest, macOS host, etc.).
# shellcheck source=config/lib/claude-login-env.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/claude-login-env.sh"

SANDBOX="${SANDBOX:-$HOME/ai-sandbox}"
if [[ -d "$SANDBOX" ]]; then
  SANDBOX="$(cd "$SANDBOX" && pwd)"
else
  SANDBOX="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

GCLOUD_RPM_DOC='https://cloud.google.com/sdk/docs/install-sdk#rpm'
GCLOUD_MAC_DOC='https://cloud.google.com/sdk/docs/install-sdk#mac'
GCLOUD_HOME='https://cloud.google.com/sdk/docs/install-sdk'

RH_RESPONSIBLE_USE_FORM='https://docs.google.com/forms/d/e/1FAIpQLSdIphsk9TlTR-TPSsk9xiNLqmgSCJJ2BLTOWLMM667X1vmsMg/viewform'
RH_GCP_PROJECT_SHEET='https://docs.google.com/spreadsheets/d/1qWoCx3i5jZ-t6BUD-2AIdutk9sMmkytoXqjBXh2oi4U/edit?gid=0#gid=0'

ANTHROPIC_CLAUDE_CODE_DOCS='https://code.claude.com/docs/en/overview'
ANTHROPIC_INSTALL_LINUX_MAC='https://claude.ai/install.sh'
ANTHROPIC_USAGE_POLICY='https://www.anthropic.com/legal/aup'

QUOTA_PROJECT_STATIC='cloudability-it-gemini'

die() {
  echo "Error: $*" >&2
  exit 1
}

os_kind() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo other ;;
  esac
}

prompt_yes() {
  local prompt="$1"
  local reply
  read -r -p "$prompt [y/N]: " reply || true
  [[ "${reply,,}" == y || "${reply,,}" == yes ]]
}

# Open a URL in the default browser (best effort).
open_url() {
  local url="$1"
  echo "  → $url"
  case "$(os_kind)" in
    macos)
      open "$url" 2>/dev/null || true
      ;;
    linux)
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" 2>/dev/null || true
      elif command -v sensible-browser >/dev/null 2>&1; then
        sensible-browser "$url" 2>/dev/null || true
      fi
      ;;
    windows)
      cmd.exe /c start "" "$url" 2>/dev/null || true
      ;;
  esac
}

# Google Cloud project IDs: 6–30 chars, lowercase letter start, end with letter or digit, interior letters/digits/hyphens.
validate_gcp_project_id() {
  local id="$1"
  [[ "$id" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] || return 1
  return 0
}

vertex_env_body() {
  local project_id="$1"
  # %q so . claude-vertex.env never breaks on () or spaces in a bad paste
  {
    echo "export CLAUDE_CODE_USE_VERTEX=1"
    echo "export CLOUD_ML_REGION=us-east5"
    printf 'export ANTHROPIC_VERTEX_PROJECT_ID=%q\n' "$project_id"
  }
}

# Write Vertex env to ~/.config and to the sandbox (secrets/ or workspace fallback).
persist_vertex_env_all() {
  local project_id="$1"
  local body
  body="$(vertex_env_body "$project_id")"

  mkdir -p "$HOME/.config/ai-sandbox"
  umask 077
  printf '%s\n' "$body" >"$HOME/.config/ai-sandbox/claude-vertex.env"
  chmod 600 "$HOME/.config/ai-sandbox/claude-vertex.env"
  echo "Wrote $HOME/.config/ai-sandbox/claude-vertex.env"

  local secrets_dest="$SANDBOX/secrets/claude-vertex.env"
  local ws_dir="$SANDBOX/workspace/.ai-sandbox-private"
  local ws_dest="$ws_dir/claude-vertex.env"

  mkdir -p "$SANDBOX/secrets" 2>/dev/null || true
  mkdir -p "$ws_dir" 2>/dev/null || true

  if printf '%s\n' "$body" >"$secrets_dest" 2>/dev/null && chmod 600 "$secrets_dest" 2>/dev/null; then
    echo "Wrote host secret: $secrets_dest"
    return 0
  fi

  if printf '%s\n' "$body" >"$ws_dest" 2>/dev/null && chmod 600 "$ws_dest" 2>/dev/null; then
    echo "Wrote host-backed file (use when secrets/ is read-only from the VM): $ws_dest"
    return 0
  fi

  echo "Note: could not write under secrets/ or workspace/.ai-sandbox-private/; ~/.config file is still valid on this machine." >&2
}

install_login_hooks() {
  ai_sandbox_install_claude_login_hook "$HOME/.bashrc"
  if [[ -f "$HOME/.zshrc" ]] || [[ "${SHELL:-}" == */zsh ]]; then
    ai_sandbox_install_claude_login_hook "$HOME/.zshrc"
  fi
}

# Numbered menu: official install.sh | npm | skip. Windows: PowerShell only + skip.
choose_and_run_claude_install() {
  local choice="1"
  echo ""

  if [[ "$(os_kind)" == windows ]]; then
    echo "On Windows, install Claude Code with PowerShell (browser will open the script URL if needed):"
    echo '  irm https://claude.ai/install.ps1 | Out-File claude-install.ps1; .\\claude-install.ps1'
    open_url "https://claude.ai/install.ps1"
    read -r -p "Press Enter when you have finished installing, or to skip..." || true
    return 0
  fi

  echo "How should Claude Code be installed?"
  echo "  1) Official install script (curl https://claude.ai/install.sh) — recommended by Anthropic"
  echo "  2) npm global: sudo npm install -g @anthropic-ai/claude-code"
  echo "  3) Skip — already installed or you will install manually"
  read -r -p "Enter 1, 2, or 3 [default: 1]: " choice || true
  choice="${choice:-1}"
  choice="${choice//[[:space:]]/}"

  case "$choice" in
    1)
      echo "Downloading and running the official installer..."
      local tmp
      tmp="$(mktemp -d)/claude-install.sh"
      curl -fsSL "$ANTHROPIC_INSTALL_LINUX_MAC" -o "$tmp"
      chmod +x "$tmp"
      "$tmp"
      ;;
    2)
      echo "Installing via npm..."
      sudo npm install -g @anthropic-ai/claude-code
      ;;
    3)
      echo "Skipped Claude Code install."
      ;;
    *)
      echo "Unrecognized choice; skipping install."
      ;;
  esac
}

# Ask if form already done; only open browser if not.
red_hat_form_acknowledgement() {
  echo ""
  echo "Red Hat requires an internal confirmation form (responsible use, policies, Claude Code user guide, etc.)."
  echo "Form: $RH_RESPONSIBLE_USE_FORM"
  if prompt_yes "Have you already submitted this form?"; then
    echo "Continuing."
    return 0
  fi
  echo "Opening the form in your browser. Submit it, then return here."
  open_url "$RH_RESPONSIBLE_USE_FORM"
  read -r -p "Press Enter after you have submitted the form." _ || true
  echo ""
}

# Collect GCP project ID before gcloud auth and before any Claude Code install (see install-inside-vm.sh order). Nameref.
collect_gcp_project_id_early() {
  local -n _out="$1"
  echo ""
  echo "— GCP project ID (required next for gcloud and Vertex; asked before Claude Code is installed) —"
  echo "Enter your team GCP project ID (from the internal spreadsheet — column C, aligned to your org / manager)."
  echo "Spreadsheet: $RH_GCP_PROJECT_SHEET"
  if prompt_yes "Open the spreadsheet in your browser now?"; then
    open_url "$RH_GCP_PROJECT_SHEET"
  fi
  _out=""
  while true; do
    read -r -p "GCP project ID: " _out || true
    _out="${_out//[[:space:]]/}"
    if [[ -z "$_out" ]]; then
      echo "Project ID cannot be empty." >&2
      continue
    fi
    if validate_gcp_project_id "$_out"; then
      return 0
    fi
    echo "That does not look like a GCP project ID (expect 6–30 chars: start with a–z, end with letter or digit, lowercase letters/digits/hyphens only — e.g. my-team-dev). Paste only the ID from the spreadsheet, not other text." >&2
  done
}

# Install google-cloud-cli on Fedora/RHEL/CentOS when missing (no extra y/n).
ensure_gcloud_installed_fedora_family() {
  if command -v gcloud >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$(os_kind)" != linux ]] || [[ ! -r /etc/os-release ]]; then
    return 1
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != fedora && "${ID:-}" != rhel && "${ID:-}" != centos ]]; then
    return 1
  fi
  echo "Installing google-cloud-cli via dnf (sudo; see $GCLOUD_RPM_DOC)..."
  sudo bash "$SCRIPT_DIR/install-google-cloud-cli-fedora.sh"
}

# Sign in, set project (avoids gcloud init project picker), ADC login + quota project — no y/n prompts.
run_red_hat_gcloud_auth() {
  local project_id="$1"
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud is not installed. Install from $GCLOUD_HOME then re-run this script, or run manually:"
    echo "  gcloud auth login"
    echo "  gcloud config set project $project_id"
    echo "  gcloud auth application-default login"
    echo "  gcloud auth application-default set-quota-project $QUOTA_PROJECT_STATIC"
    return 1
  fi

  local active
  active="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n1 || true)"
  if [[ -z "$active" ]]; then
    echo "Sign in to Google Cloud with your Red Hat account (browser may open)..."
    gcloud auth login || true
  else
    echo "gcloud already has an active account: $active"
  fi

  echo "Setting gcloud project to $project_id (no project list / gcloud init)."
  gcloud config set project "$project_id" || true

  echo "Application Default Credentials (browser may open; ignore errors from the first command if any, then quota is set)..."
  gcloud auth application-default login || true
  gcloud auth application-default set-quota-project "$QUOTA_PROJECT_STATIC" || {
    echo "Warning: set-quota-project failed; retry after ADC login succeeds." >&2
  }
}

persist_api_key_if_needed() {
  local key="$1"
  local secrets_dest="$SANDBOX/secrets/claude_api_key"
  local ws_dir="$SANDBOX/workspace/.ai-sandbox-private"
  local ws_dest="$ws_dir/claude_api_key"

  mkdir -p "$SANDBOX/secrets" 2>/dev/null || true
  mkdir -p "$ws_dir" 2>/dev/null || true

  if printf '%s\n' "$key" >"$secrets_dest" 2>/dev/null && chmod 600 "$secrets_dest" 2>/dev/null; then
    echo "Wrote $secrets_dest"
    return 0
  fi
  if printf '%s\n' "$key" >"$ws_dest" 2>/dev/null && chmod 600 "$ws_dest" 2>/dev/null; then
    echo "Wrote $ws_dest (host-backed; use when secrets/ is read-only from the VM)"
    return 0
  fi
  echo "Could not write API key under secrets/ or workspace/.ai-sandbox-private/." >&2
  return 1
}

run_red_hat_path() {
  echo ""
  echo "=== Red Hat employee — Claude Code (Vertex) setup ==="

  red_hat_form_acknowledgement

  local project_id
  collect_gcp_project_id_early project_id

  case "$(os_kind)" in
    linux)
      if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
      fi
      if [[ "${ID:-}" == fedora || "${ID:-}" == rhel || "${ID:-}" == centos ]]; then
        ensure_gcloud_installed_fedora_family || true
      else
        echo "Install Google Cloud CLI: $GCLOUD_HOME"
        open_url "$GCLOUD_HOME"
      fi
      ;;
    macos)
      echo "Install Google Cloud CLI: $GCLOUD_MAC_DOC"
      open_url "$GCLOUD_MAC_DOC"
      ;;
    *)
      echo "Install Google Cloud CLI: $GCLOUD_HOME"
      open_url "$GCLOUD_HOME"
      ;;
  esac

  echo ""
  run_red_hat_gcloud_auth "$project_id"

  persist_vertex_env_all "$project_id"
  install_login_hooks

  choose_and_run_claude_install

  echo ""
  echo "Open a new terminal (or: source ~/.bashrc / source ~/.zshrc), cd to your project directory, then run:  claude"
  if [[ "${AI_SANDBOX_SETUP_FROM_INSTALL:-}" != "1" ]]; then
    echo "If ~/.claude merge has not run yet:  ~/ai-sandbox/config/install-inside-vm.sh"
  fi
}

run_anthropic_standard_path() {
  echo ""
  echo "=== Standard (non–Red Hat) Claude Code setup ==="

  echo "Docs: $ANTHROPIC_CLAUDE_CODE_DOCS"
  echo "Usage policy: $ANTHROPIC_USAGE_POLICY"
  if prompt_yes "Have you already reviewed these?"; then
    :
  else
    echo "Opening in your browser."
    open_url "$ANTHROPIC_CLAUDE_CODE_DOCS"
    open_url "$ANTHROPIC_USAGE_POLICY"
    read -r -p "Press Enter when you are ready to continue." _ || true
  fi

  local have_key=0
  if [[ -r "$SANDBOX/secrets/claude_api_key" ]] || [[ -r "$SANDBOX/workspace/.ai-sandbox-private/claude_api_key" ]]; then
    echo "Found existing API key file under secrets/ or workspace/.ai-sandbox-private/"
    have_key=1
  fi

  if [[ "$have_key" -eq 0 ]]; then
    echo ""
    echo "Enter your Anthropic API key (input hidden). It will be saved under secrets/ or workspace/.ai-sandbox-private/."
    local key=""
    read -r -s -p "API key: " key || true
    echo ""
    key="${key//[[:space:]]/}"
    if [[ -n "$key" ]]; then
      persist_api_key_if_needed "$key" || {
        echo "Save the key yourself at $SANDBOX/secrets/claude_api_key (host), one line, chmod 600." >&2
      }
    else
      echo "No key entered. Create $SANDBOX/secrets/claude_api_key on the host (one line), then re-run install-inside-vm.sh."
    fi
  fi

  choose_and_run_claude_install

  echo ""
  if [[ "${AI_SANDBOX_SETUP_FROM_INSTALL:-}" != "1" ]]; then
    echo "In the Fedora VM, run ~/ai-sandbox/config/install-inside-vm.sh to merge ~/.claude settings and MCP bootstrap."
  fi
}

main() {
  echo "Claude Code setup helper (ai-sandbox)"
  echo "Sandbox root: $SANDBOX"
  echo ""

  local rh=""
  read -r -p "Are you a Red Hat employee? [y/N]: " rh || true
  rh="${rh,,}"

  if [[ "$rh" == y || "$rh" == yes ]]; then
    run_red_hat_path
  else
    run_anthropic_standard_path
  fi
}

main "$@"
