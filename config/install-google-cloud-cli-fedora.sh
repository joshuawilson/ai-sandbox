#!/usr/bin/env bash
# Install Google Cloud CLI on Fedora / RHEL-like systems via Google's DNF repository.
# Official reference: https://cloud.google.com/sdk/docs/install-sdk#rpm
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "dnf not found; use Google's Linux tarball or OS-specific guide:" >&2
  echo "https://cloud.google.com/sdk/docs/install-sdk" >&2
  exit 1
fi

if command -v gcloud >/dev/null 2>&1; then
  echo "gcloud already on PATH: $(command -v gcloud)"
  exit 0
fi

arch="$(uname -m)"
case "$arch" in
  x86_64) baseurl="https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64" ;;
  aarch64) baseurl="https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-aarch64" ;;
  *)
    echo "Unsupported architecture: $arch — install manually:" >&2
    echo "https://cloud.google.com/sdk/docs/install-sdk#linux" >&2
    exit 1
    ;;
esac

repo="/etc/yum.repos.d/google-cloud-sdk.repo"
if [[ ! -f "$repo" ]] || ! grep -q '^\[google-cloud-cli\]' "$repo" 2>/dev/null; then
  cat >"$repo" <<EOF
[google-cloud-cli]
name=Google Cloud CLI
baseurl=$baseurl
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
  echo "Wrote $repo"
fi

dnf install -y libxcrypt-compat google-cloud-cli
echo "Installed google-cloud-cli. Next: gcloud auth login, gcloud config set project YOUR_ID, gcloud auth application-default login (see setup-claude.sh / company docs)."
