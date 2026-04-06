#!/usr/bin/env bash
# Create secrets/vm-password.env with a random password for kickstart user "ai" on the Fedora VM.
# Cursor runs in that VM session—not inside Podman—so this is your VM login/unlock password, not a "container UI" password.
# The cleartext stays in this file on the host; you can "cat" it anytime.
#
# Writes to this repo's secrets/ (directory containing host/). If the file is missing, empty, or has no VM_PASSWORD= line,
# a new password is set. Use --force to replace an existing file.
#
# Password source: openssl → python3 → /dev/urandom+base64. If none are available, offers
# "sudo dnf install -y openssl" on Fedora, or prompts you to type a password (TTY only).
# Use --manual to always prompt (TTY); used by host/configure-vm-host.sh when you decline auto-generation.
set -euo pipefail

HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$HOST_DIR/.." && pwd)"
F="$BASE/secrets/vm-password.env"

force=false
manual=false
for arg in "$@"; do
  case "$arg" in
    --force) force=true ;;
    --manual) manual=true ;;
    -h | --help)
      echo "Usage: $(basename "$0") [--force] [--manual]"
      echo "  Writes $BASE/secrets/vm-password.env with VM_PASSWORD=... (generated or typed)."
      echo "  --force   Replace an existing file."
      echo "  --manual  Prompt for password twice (TTY); does not auto-generate."
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

password_line_ok() {
  [[ -f "$F" && -s "$F" ]] || return 1
  grep -qE '^[[:space:]]*VM_PASSWORD[[:space:]]*=' "$F"
}

gen_pw_or_fail() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets; print(secrets.token_urlsafe(24))"
    return 0
  fi
  if command -v base64 >/dev/null 2>&1 && [[ -r /dev/urandom ]]; then
    head -c 24 /dev/urandom | base64 | tr -d '\n\r '
    echo ""
    return 0
  fi
  return 1
}

try_install_openssl_fedora() {
  command -v openssl >/dev/null 2>&1 && return 0
  [[ -t 0 ]] || return 1
  [[ -f /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "fedora" ]] || return 1
  command -v dnf >/dev/null 2>&1 || return 1
  local a
  read -r -p "openssl not found. Install with: sudo dnf install -y openssl ? [y/N] " a
  case "$a" in
    y | Y | yes | YES) sudo dnf install -y openssl ;;
    *) return 1 ;;
  esac
  command -v openssl >/dev/null 2>&1
}

prompt_manual_password() {
  # IDEs and some wrappers run scripts with stdin/stdout not a TTY; /dev/tty is still the real terminal.
  local use_tty=false
  if [[ -r /dev/tty ]] && [[ -w /dev/tty ]]; then
    use_tty=true
  elif [[ -t 0 ]] && [[ -t 1 ]]; then
    use_tty=false
  else
    echo "Cannot prompt: no interactive terminal (stdin/stdout not a TTY and /dev/tty unavailable)." >&2
    echo "Create $F yourself with:  VM_PASSWORD='your-password'" >&2
    echo "Or run this script from a normal terminal (or ssh -t)." >&2
    exit 1
  fi
  local a b
  while true; do
    if [[ "$use_tty" == true ]]; then
      read -r -s -p "Enter VM password for kickstart user 'ai': " a < /dev/tty
      echo > /dev/tty
      read -r -s -p "Confirm: " b < /dev/tty
      echo > /dev/tty
    else
      read -r -s -p "Enter VM password for kickstart user 'ai': " a
      echo
      read -r -s -p "Confirm: " b
      echo
    fi
    if [[ -z "$a" ]]; then
      echo "Password cannot be empty." >&2
      continue
    fi
    if [[ "$a" != "$b" ]]; then
      echo "Passwords do not match." >&2
      continue
    fi
    printf '%s' "$a"
    return 0
  done
}

write_password_file() {
  local pw="$1"
  pw="${pw//$'\r'/}"
  pw="${pw//$'\n'/}"
  umask 077
  mkdir -p "$BASE/secrets"
  # Shell-safe for: source "$F" (handles quotes and spaces in password)
  printf 'VM_PASSWORD=%q\n' "$pw" >"$F"
  chmod 600 "$F" 2>/dev/null || true
  echo "Wrote $F"
  echo "VM_PASSWORD is set (see file; value may contain special characters)."
  echo "Store this password safely; it is used for the VM user in kickstart."
}

if [[ "$manual" == true ]]; then
  if [[ "$force" != true ]] && password_line_ok; then
    if [[ -r /dev/tty ]] && [[ -w /dev/tty ]]; then
      read -r -p "Overwrite existing $F? [y/N] " ov < /dev/tty || true
    else
      read -r -p "Overwrite existing $F? [y/N] " ov || true
    fi
    case "${ov:-n}" in
      y | Y | yes) ;;
      *)
        echo "Keeping existing $F"
        exit 0
        ;;
    esac
  fi
  echo "Enter a password for kickstart user 'ai' (stored in $F)."
  pw="$(prompt_manual_password)"
  write_password_file "$pw"
  if ! command -v openssl >/dev/null 2>&1; then
    echo "" >&2
    echo "Note: host/generate-ks-fedora.sh uses openssl to hash this password for kickstart." >&2
    echo "Install openssl before create-vm (e.g. sudo dnf install openssl)." >&2
  fi
  exit 0
fi

if [[ "$force" != true ]] && password_line_ok; then
  echo "Already exists (unchanged): $F"
  exit 0
fi

mkdir -p "$BASE/secrets"

pw=""
if out="$(gen_pw_or_fail)"; then
  pw="$out"
elif try_install_openssl_fedora && out="$(gen_pw_or_fail)"; then
  pw="$out"
else
  echo "Could not generate a random password (install openssl, python3, or coreutils base64). Typing password interactively." >&2
  pw="$(prompt_manual_password)"
fi

write_password_file "$pw"

if ! command -v openssl >/dev/null 2>&1; then
  echo "" >&2
  echo "Note: host/generate-ks-fedora.sh uses openssl to hash this password for kickstart." >&2
  echo "Install openssl before create-vm (e.g. sudo dnf install openssl)." >&2
fi
