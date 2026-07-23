#!/bin/bash
# Remove the RuntimeCommand Docker container and optionally its data.
#
# Stops and removes the code-server Docker container. With `--purge`,
# also removes the Docker home directory (CodeServerDockerHome) and all
# persisted state (XDG dirs, settings, sessions, etc.).
#
# Args
# ----
# - `--purge`
#     Also remove the Docker home directory and all persisted data.
#     Without this flag, only the container is removed (data survives
#     for the next `wrapper.sh` cold-start).
# - `--yes`
#     Skip confirmation prompts.
#
# Returns
# -------
# (No-Returns)
#
# Examples
# --------
# ```
# bash remove.sh          # Remove container only (data preserved)
# bash remove.sh --purge  # Remove container + all Docker home data
# bash remove.sh --yes    # Skip confirmation
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load shared configuration (provides CONTAINER_NAME, DOCKER_HOME, etc.).
source "${PROJECT_ROOT}/config.sh"

# Parse flags.
PURGE=0
YES=0
while [[ $# -gt 0 ]]; do
    case "${1}" in
    --purge)
        PURGE=1
        shift
        ;;
    --yes | -y)
        YES=1
        shift
        ;;
    *)
        echo "Unknown argument: ${1}" >&2
        exit 1
        ;;
    esac
done

# Confirmation prompt.
_confirm() {
    if [[ "${YES}" -eq 1 ]]; then return 0; fi
    echo -n "$1 [y/N] "
    read -r answer
    [[ "${answer}" =~ ^[Yy] ]]
}

echo "RuntimeCommand Remove"
echo "====================="
echo "Container: ${CONTAINER_NAME}"
echo "Docker Home: ${DOCKER_HOME}"
echo ""

# Step 0: Remove the 4am restart cron entry so it doesn't recreate the
# container after removal. Idempotent — a no-op if no entry is installed.
bash "${PROJECT_ROOT}/cron_setup.sh" --remove

# Step 1: Stop and remove the container.
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if _confirm "Remove container \`${CONTAINER_NAME}\`?"; then
        docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1
        echo "✓ Container \`${CONTAINER_NAME}\` removed."
    else
        echo "Skipped container removal."
    fi
else
    echo "✓ Container \`${CONTAINER_NAME}\` does not exist."
fi

# Step 2: Optionally purge Docker home.
if [[ "${PURGE}" -eq 1 ]]; then
    if [[ -d "${DOCKER_HOME}" ]]; then
        if _confirm "DELETE Docker home \`${DOCKER_HOME}\` and all data? THIS CANNOT BE UNDONE."; then
            rm -rf "${DOCKER_HOME}"
            echo "✓ Docker home \`${DOCKER_HOME}\` removed."
        else
            echo "Skipped Docker home removal."
        fi
    else
        echo "✓ Docker home \`${DOCKER_HOME}\` does not exist."
    fi
fi

echo ""
echo "Done. Run \`bash ${SCRIPT_DIR}/wrapper.sh --detach\` to create a fresh container."
