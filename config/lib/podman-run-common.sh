# shellcheck shell=bash
# Common podman run logic for ai-dev containers.
# Sourced by start-container.sh and restore-project.sh after all prerequisites are set up.
#
# Prerequisites (must be set before sourcing):
#   - NAME: project name
#   - CONTAINER_IMAGE or IMAGE_ARG: image to run
#   - RUN_FLAGS: array of -d or -it flags
#   - DEV_HOME_DIR: path to container home overlay
#   - All volume arrays from podman-workspace-volumes.sh
#   - All security/resource limits from container.env
#   - PODMAN_VERTEX_ENV_FILE and PODMAN_VERTEX_VOLS from podman-vertex-container-opts.sh

ai_sandbox_run_dev_container() {
  local name="${1:?ai_sandbox_run_dev_container: NAME required}"
  local image="${2:?ai_sandbox_run_dev_container: IMAGE required}"
  shift 2
  local -a extra_flags=("$@")

  PODMAN_VERTEX_EXTRA=()
  [[ -n "${PODMAN_VERTEX_ENV_FILE:-}" ]] && PODMAN_VERTEX_EXTRA+=(--env-file "$PODMAN_VERTEX_ENV_FILE")
  PODMAN_VERTEX_EXTRA+=("${PODMAN_VERTEX_VOLS[@]}")

  podman run \
    "${extra_flags[@]}" \
    --name "ai-dev-$name" \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    "${PODMAN_SEC_EXTRA[@]}" \
    --userns=keep-id \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/dev \
    -e DISABLE_AUTOUPDATER=1 \
    -w /workspace \
    --read-only \
    --tmpfs /run \
    --tmpfs /tmp \
    "${VOL_DEVHOME[@]}" \
    --pids-limit="$PID_LIMIT" \
    --memory="$MEMORY_LIMIT" \
    --cpus="$CPU_LIMIT" \
    --network slirp4netns \
    "${VOL_MIRROR[@]}" \
    "${VOL_WORKSPACE[@]}" \
    "${VOL_SSH[@]}" \
    "${PODMAN_VERTEX_EXTRA[@]}" \
    "$image"

  [[ -n "${PODMAN_VERTEX_ENV_FILE:-}" ]] && rm -f "$PODMAN_VERTEX_ENV_FILE"
}
