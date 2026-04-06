# shellcheck shell=bash
# Optional Vertex + gcloud inside the dev container. Sourced by start-container.sh / restore-project.sh.
#
# Sets:
#   PODMAN_VERTEX_ENV_FILE — path to a temp env-file for podman (caller removes after podman run), or empty
#   PODMAN_VERTEX_VOLS — bash array of extra -v flags (gcloud config)
#
# The guest VM's ~/.bashrc does not apply inside podman; ADC lives in ~/.config/gcloud and must be mounted.

ai_sandbox_prepare_podman_vertex() {
  PODMAN_VERTEX_ENV_FILE=""
  PODMAN_VERTEX_VOLS=()

  local vf="$HOME/.config/ai-sandbox/claude-vertex.env"
  if [[ -f "$vf" ]]; then
    PODMAN_VERTEX_ENV_FILE="$(mktemp)"
    if ! (
      set -a
      # shellcheck disable=SC1090
      source "$vf"
      set +a
      : >"$PODMAN_VERTEX_ENV_FILE"
      [[ -n "${CLAUDE_CODE_USE_VERTEX:-}" ]] && printf 'CLAUDE_CODE_USE_VERTEX=%s\n' "$CLAUDE_CODE_USE_VERTEX" >>"$PODMAN_VERTEX_ENV_FILE"
      [[ -n "${CLOUD_ML_REGION:-}" ]] && printf 'CLOUD_ML_REGION=%s\n' "$CLOUD_ML_REGION" >>"$PODMAN_VERTEX_ENV_FILE"
      [[ -n "${ANTHROPIC_VERTEX_PROJECT_ID:-}" ]] && printf 'ANTHROPIC_VERTEX_PROJECT_ID=%s\n' "$ANTHROPIC_VERTEX_PROJECT_ID" >>"$PODMAN_VERTEX_ENV_FILE"
    ); then
      rm -f "$PODMAN_VERTEX_ENV_FILE"
      PODMAN_VERTEX_ENV_FILE=""
      echo "ai-sandbox: warning: could not parse $vf for container env; fix syntax or run setup-claude.sh" >&2
    elif [[ ! -s "$PODMAN_VERTEX_ENV_FILE" ]]; then
      rm -f "$PODMAN_VERTEX_ENV_FILE"
      PODMAN_VERTEX_ENV_FILE=""
    fi
  fi

  local gd="$HOME/.config/gcloud"
  if [[ -d "$gd" ]]; then
    local suf=":ro"
    [[ "${AI_SANDBOX_PODMAN_LABEL_DISABLE:-0}" != 1 ]] && suf=":ro,z"
    PODMAN_VERTEX_VOLS+=(-v "$gd:/home/dev/.config/gcloud$suf")
  fi
}
