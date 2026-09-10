#!/bin/bash
# Shared container removal logic for all platforms.
#
# Provides reusable functions for stopping/removing the Docker container
# and optionally purging the Docker home directory. Platform-specific
# remove scripts (`linux/remove.sh`, `macos/remove.sh`) source this file
# after sourcing `config.sh`, then call `_remove_run`.
#
# The caller must have already sourced `config.sh` (provides
# `CONTAINER_RUNTIME`, `CONTAINER_NAME`, `DOCKER_HOME`).
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)

# Prevent redundant sourcing.
[[ ${_REMOVE_COMMON_SH_LOADED:-0} -eq 1 ]] && return
_REMOVE_COMMON_SH_LOADED=1

# Resolve paths relative to remove_common.sh (the project root).
_REMOVE_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Confirmation prompt helper.
#
# When `YES=1` is set (by `--yes` flag), auto-confirms. Otherwise prompts
# the user for y/N confirmation.
#
# Args
# ----
# - `prompt`
#     The confirmation message to display.
#
# Returns
# -------
# - `status`
#     0 if confirmed, 1 if declined.
_remove_confirm() {
    if [[ "${YES}" -eq 1 ]]; then return 0; fi
    echo -n "$1 [y/N] "
    read -r answer
    [[ "${answer}" =~ ^[Yy] ]]
}

# Run the full removal sequence.
#
# Parses `--purge` and `--yes` flags, removes the cron job (if the cron
# setup script exists), stops and removes the container, and optionally
# purges the Docker home directory.
#
# Args
# ----
# - `$@`
#     Command-line arguments (`--purge`, `--yes`/`-y`).
#
# Returns
# -------
# (No-Returns)
_remove_run() {
    # Parse flags.
    local PURGE=0
    local YES=0
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

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

    echo "RuntimeCommand Remove"
    echo "====================="
    echo "Container: ${CONTAINER_NAME}"
    echo "Docker Home: ${DOCKER_HOME}"
    echo ""

    # Step 0: Remove the 4am restart cron entry so it doesn't recreate the
    # container after removal. Idempotent — a no-op if no entry is installed.
    if [[ -f "${_REMOVE_COMMON_DIR}/cron_setup.sh" ]]; then
        bash "${_REMOVE_COMMON_DIR}/cron_setup.sh" --remove
    fi

    # Step 1: Stop and remove the container.
    if ${CONTAINER_RUNTIME} ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        if _remove_confirm "Remove container \`${CONTAINER_NAME}\`?"; then
            ${CONTAINER_RUNTIME} rm -f "${CONTAINER_NAME}" >/dev/null 2>&1
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
            if _remove_confirm "DELETE Docker home \`${DOCKER_HOME}\` and all data? THIS CANNOT BE UNDONE."; then
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
    echo "Done. Run \`bash ${script_dir}/wrapper.sh --detach\` to create a fresh container."
}
