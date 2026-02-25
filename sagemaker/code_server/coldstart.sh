#!/bin/bash
# Bootstrap code-server settings and extensions for Docker code-server.
#
# Symlinks User settings from the shared repo directory and templates Machine
# settings (with default Python path) to the code-server data
# directory, installs the `zokugun.sync-settings` extension, and templates
# the sync-settings configuration with the resolved project root path.
# Shared settings come from `docker/code_server/`, while SageMaker-specific
# settings come from `docker/sagemaker/code_server/`.
#
# Args
# ----
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--quiet`
#     When set, suppresses step-by-step log output.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# After running this script, open code-server and run the command palette
# action "Sync Settings: Download (repository -> user)" to apply extensions.
#
# Examples
# --------
# ```
# bash coldstart.sh
# bash coldstart.sh --quiet
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
SAGEMAKER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${SAGEMAKER_ROOT}/.." && pwd)"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH, QUIET via --log-depth, --quiet).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides XDG_DATA_HOME, IMAGE_NAME, IMAGE_TAG, etc.).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve quiet flag from argparse (--quiet sets QUIET=1).
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# Shared and SageMaker-specific code-server source directories.
SHARED_CS_ROOT="${PROJECT_ROOT}/code_server"
SAGEMAKER_CS_ROOT="${SCRIPT_DIR}"
CODE_SERVER_SETTINGS_ROOT="${XDG_DATA_HOME}/code-server"

# Print coldstart header.
log_log "${QUIET}" "Code-Server Coldstart"

# Symlink User settings (shared) to code-server data directory.
log_log "${QUIET}" "[1/4] Linking User settings ..."
HERE="${SHARED_CS_ROOT}/User/settings.json"
THERE="${CODE_SERVER_SETTINGS_ROOT}/User/settings.json"
if [[ ! -L "${THERE}" || "$(readlink -f "${THERE}")" != "$(readlink -f "${HERE}")" ]]; then
    if [[ -f "${THERE}" ]]; then
        mv "${THERE}" "${THERE}.bak"
        rm -f "${HERE}.bak"
        ln -s "${THERE}.bak" "${HERE}.bak"
    else
        rm -f "${THERE}"
    fi
    mkdir -p "$(dirname "${THERE}")"
    ln -s "${HERE}" "${THERE}"
fi

# Template and symlink Machine settings (SageMaker-specific).
# Uses the default Python path since mise runtimes are installed inside the
# Docker container, not on the host where this script runs.
log_log "${QUIET}" "[2/4] Templating Machine settings ..."
MISE_PYTHON_PATH="/usr/bin/python3"
log_log "${QUIET}" "Python path: ${MISE_PYTHON_PATH}"
log_log "${QUIET}" "Docker shell: ${DOCKER_SHELL}"
rm -f "${SAGEMAKER_CS_ROOT}/Machine/settings.json"
cp "${SAGEMAKER_CS_ROOT}/Machine/settings-template.json" "${SAGEMAKER_CS_ROOT}/Machine/settings.json"
MISE_PYTHON_PATH_SED="$(echo "${MISE_PYTHON_PATH}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
DOCKER_SHELL_SED="$(echo "${DOCKER_SHELL}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
sed -i -e "s/\${MISE_PYTHON_PATH}/${MISE_PYTHON_PATH_SED}/g" \
    -e "s/\${DOCKER_SHELL}/${DOCKER_SHELL_SED}/g" \
    "${SAGEMAKER_CS_ROOT}/Machine/settings.json"
HERE="${SAGEMAKER_CS_ROOT}/Machine/settings.json"
THERE="${CODE_SERVER_SETTINGS_ROOT}/Machine/settings.json"
if [[ ! -L "${THERE}" || "$(readlink -f "${THERE}")" != "$(readlink -f "${HERE}")" ]]; then
    if [[ -f "${THERE}" ]]; then
        mv "${THERE}" "${THERE}.bak"
        rm -f "${HERE}.bak"
        ln -s "${THERE}.bak" "${HERE}.bak"
    else
        rm -f "${THERE}"
    fi
    mkdir -p "$(dirname "${THERE}")"
    ln -s "${HERE}" "${THERE}"
fi

# Install sync-settings extension if not already present.
log_log "${QUIET}" "[3/4] Installing sync-settings extension ..."
SYNC_SETTINGS_SOURCE_ROOT="${SAGEMAKER_CS_ROOT}/User/globalStorage/zokugun.sync-settings"
SYNC_SETTINGS_SETTINGS_ROOT="${CODE_SERVER_SETTINGS_ROOT}/User/globalStorage/zokugun.sync-settings"
if [[ ! -d "${SYNC_SETTINGS_SETTINGS_ROOT}" ]]; then
    docker run --rm \
        --security-opt label:disable \
        -e "HOME=${DOCKER_HOME}" \
        -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
        -v "${DOCKER_HOME}:${DOCKER_HOME}" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        --install-extension zokugun.sync-settings
fi

# Template and symlink sync-settings configuration.
log_log "${QUIET}" "[4/4] Configuring sync-settings ..."
rm -f "${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
cp "${SYNC_SETTINGS_SOURCE_ROOT}/settings-template.yml" "${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
PROJECT_ROOT_SED="$(echo "${PROJECT_ROOT}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
sed -i -e "s/\${PROJECT_ROOT}/${PROJECT_ROOT_SED}/g" "${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
HERE="${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
THERE="${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml"
if [[ ! -L "${THERE}" || "$(readlink -f "${THERE}")" != "$(readlink -f "${HERE}")" ]]; then
    if [[ -f "${THERE}" ]]; then
        mv "${THERE}" "${THERE}.bak"
        rm -f "${HERE}.bak"
        ln -s "${THERE}.bak" "${HERE}.bak"
    else
        rm -f "${THERE}"
    fi
    mkdir -p "$(dirname "${THERE}")"
    ln -s "${HERE}" "${THERE}"
fi
log_log "${QUIET}" "Coldstart complete. Run \`Sync Settings: Download (repository -> user)\` in code-server."
