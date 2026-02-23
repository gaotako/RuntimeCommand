#!/bin/bash
# Bootstrap code-server settings and extensions for Docker code-server.
#
# Symlinks User and Machine settings from the repo to the code-server data
# directory, installs the `zokugun.sync-settings` extension, and templates
# the sync-settings configuration with the resolved project root path.
# Shared settings come from `docker/code_server/`, while SageMaker-specific
# settings come from `docker/sagemaker/code_server/`.
#
# Args
# ----
# - --log-depth LOG_DEPTH
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
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
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
SAGEMAKER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${SAGEMAKER_ROOT}/.." && pwd)"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH via --log-depth).
argparse::parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides XDG_DATA_HOME, IMAGE_NAME, IMAGE_TAG, etc.).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log::make_indent "${LOG_DEPTH}"

# Shared and SageMaker-specific code-server source directories.
SHARED_CS_ROOT="${PROJECT_ROOT}/code_server"
SAGEMAKER_CS_ROOT="${SCRIPT_DIR}"
CODE_SERVER_SETTINGS_ROOT="${XDG_DATA_HOME}/code-server"

# Print coldstart header.
echo "${LOG_INDENT} Code-Server Coldstart"

# Symlink User settings (shared) and Machine settings (SageMaker-specific).
echo "${LOG_INDENT} [1/3] Linking settings ..."
for profile in User Machine; do
    if [[ "${profile}" == "User" ]]; then
        here="${SHARED_CS_ROOT}/${profile}/settings.json"
    else
        here="${SAGEMAKER_CS_ROOT}/${profile}/settings.json"
    fi
    there="${CODE_SERVER_SETTINGS_ROOT}/${profile}/settings.json"
    if [[ ! -L "${there}" || "$(readlink -f "${there}")" != "$(readlink -f "${here}")" ]]; then
        if [[ -f "${there}" ]]; then
            mv "${there}" "${there}.bak"
            rm -f "${here}.bak"
            ln -s "${there}.bak" "${here}.bak"
        else
            rm -f "${there}"
        fi
        mkdir -p "$(dirname "${there}")"
        ln -s "${here}" "${there}"
    fi
done

# Install sync-settings extension if not already present.
echo "${LOG_INDENT} [2/3] Installing sync-settings extension ..."
SYNC_SETTINGS_SOURCE_ROOT="${SAGEMAKER_CS_ROOT}/User/globalStorage/zokugun.sync-settings"
SYNC_SETTINGS_SETTINGS_ROOT="${CODE_SERVER_SETTINGS_ROOT}/User/globalStorage/zokugun.sync-settings"
if [[ ! -d "${SYNC_SETTINGS_SETTINGS_ROOT}" ]]; then
    docker run --rm \
        -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
        -v "${DOCKER_HOME}:${DOCKER_HOME}" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        --install-extension zokugun.sync-settings
fi

# Template and symlink sync-settings configuration.
echo "${LOG_INDENT} [3/3] Configuring sync-settings ..."
rm -rf "${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
cp "${SYNC_SETTINGS_SOURCE_ROOT}/settings-template.yml" "${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
project_root_sed="$(echo "${PROJECT_ROOT}" | sed -E "s/([\\/\\.])/\\\\\1/g")"
sed -i -e "s/\${PROJECT_ROOT}/${project_root_sed}/g" "${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
here="${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml"
there="${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml"
if [[ ! -L "${there}" || "$(readlink -f "${there}")" != "$(readlink -f "${here}")" ]]; then
    if [[ -f "${there}" ]]; then
        mv "${there}" "${there}.bak"
        rm -f "${here}.bak"
        ln -s "${there}.bak" "${here}.bak"
    else
        rm -f "${there}"
    fi
    mkdir -p "$(dirname "${there}")"
    ln -s "${here}" "${there}"
fi
echo "${LOG_INDENT} Coldstart complete. Run 'Sync Settings: Download (repository -> user)' in code-server."