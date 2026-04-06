# shellcheck shell=bash
# Sourced by start-container.sh / restore-project.sh after WORKSPACE and DEV_HOME_DIR are set.
# Populates bash arrays: PODMAN_SEC_EXTRA, VOL_WORKSPACE, VOL_MIRROR, VOL_DEVHOME, VOL_SSH.
# Requires: WORKSPACE, WORKSPACE_ROOT, DEV_HOME_DIR, HOME (container.env sourced first).

WS_FSTYPE="$(findmnt -n -o FSTYPE --target "$WORKSPACE" 2>/dev/null || true)"
LABEL_DISABLE="${AI_SANDBOX_PODMAN_LABEL_DISABLE:-}"
if [[ -z "$LABEL_DISABLE" ]]; then
  if [[ "$WS_FSTYPE" == "virtiofs" ]]; then
    LABEL_DISABLE=1
  else
    LABEL_DISABLE=0
  fi
fi

VOL_WORKSPACE=(-v "$WORKSPACE:/workspace")
VOL_DEVHOME=(-v "$DEV_HOME_DIR:/home/dev")
VOL_SSH=(-v "$HOME/.ssh:/home/dev/.ssh:ro")
PODMAN_SEC_EXTRA=()
VOL_MIRROR=(-v "$WORKSPACE_ROOT:/home/dev/ai-sandbox/workspace")
if [[ "$LABEL_DISABLE" == 1 ]]; then
  PODMAN_SEC_EXTRA=(--security-opt label=disable)
else
  VOL_WORKSPACE=(-v "$WORKSPACE:/workspace:z")
  VOL_DEVHOME=(-v "$DEV_HOME_DIR:/home/dev:Z")
  VOL_SSH=(-v "$HOME/.ssh:/home/dev/.ssh:ro,z")
  VOL_MIRROR=(-v "$WORKSPACE_ROOT:/home/dev/ai-sandbox/workspace:z")
fi

# For optional mounts (e.g. gcloud) that need :z when SELinux is enforcing.
export AI_SANDBOX_PODMAN_LABEL_DISABLE="$LABEL_DISABLE"
