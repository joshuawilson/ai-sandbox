# shellcheck shell=bash
# Resolve the ai-sandbox repository root for scripts under host/.
# Override (either): SANDBOX or AI_SANDBOX_HOME — must point at the repo root (parent of host/, config/, secrets/).
#
# Usage from host/*.sh:
#   _HS_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=lib/sandbox-root.sh
#   source "$_HS_HOST_DIR/lib/sandbox-root.sh"
#   BASE="$(sandbox_repo_root)"

sandbox_repo_root() {
  if [[ -n "${SANDBOX:-}" ]]; then
    printf '%s' "$SANDBOX"
    return 0
  fi
  if [[ -n "${AI_SANDBOX_HOME:-}" ]]; then
    printf '%s' "$AI_SANDBOX_HOME"
    return 0
  fi
  if [[ -z "${_HS_HOST_DIR:-}" ]]; then
    echo "sandbox_repo_root: set _HS_HOST_DIR to the host/ directory before sourcing sandbox-root.sh" >&2
    return 1
  fi
  printf '%s' "$(cd "$_HS_HOST_DIR/.." && pwd)"
}
