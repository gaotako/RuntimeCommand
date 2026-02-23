#!/bin/bash
# Install code-server by building the Docker image and placing a wrapper script.
#
# Builds (or loads from cache) the `code-server-sagemaker` Docker image via
# `build.sh`, backs up any existing code-server binary, installs `wrapper.sh`
# as the drop-in replacement, and verifies the image runs correctly. On
# verification failure the original binary is restored from backup.
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
# The following environment variables can override default paths:
# - `HOME`
#     User home directory.
# - `WORKSPACE`
#     SageMaker workspace root.
# - `APP_ROOT`
#     Application root directory.
# - `APP_DATA_HOME`
#     Application data directory.
# - `CODE_SERVER_APPLICATION`
#     code-server application directory.
# - `CODE_SERVER`
#     Path to the code-server binary / wrapper.
# - `CODE_SERVER_VERSION`
#     code-server version to install (default: `"latest"`).
#
# Examples
# --------
# ```
# bash install.sh
# CODE_SERVER_VERSION=4.109.2 bash install.sh
# bash install.sh --log-depth 2
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH via --log-depth).
argparse::parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (respects values already set by argparse).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log::make_indent "${LOG_DEPTH}"

# Print installation header.
echo "${LOG_INDENT} Code-Server Docker Installer"
echo "${LOG_INDENT} Target: ${CODE_SERVER}"

# Verify Docker is installed and available on PATH.
if ! command -v docker &>/dev/null; then
    echo "${LOG_INDENT} ERROR: Docker is not installed or not in PATH."
    exit 1
fi
echo "${LOG_INDENT} [1/4] Docker is available: $(docker --version)"

# Build (or load from cache) the Docker image.
echo "${LOG_INDENT} [2/4] Building Docker image ..."
bash "${PROJECT_ROOT}/build.sh" --log-depth $((LOG_DEPTH + 1)) "${CODE_SERVER_VERSION}"

# Back up the existing binary if one is already installed.
if [ -f "${CODE_SERVER}" ]; then
    BACKUP="${CODE_SERVER}.bak.$(date +%Y%m%d%H%M%S)"
    echo "${LOG_INDENT} [3/4] Backing up existing binary to ${BACKUP}"
    cp "${CODE_SERVER}" "${BACKUP}"
else
    echo "${LOG_INDENT} [3/4] No existing binary found, skipping backup."
fi

# Install the wrapper script and config alongside it.
echo "${LOG_INDENT} [4/4] Installing wrapper script to ${CODE_SERVER}"
mkdir -p "$(dirname "${CODE_SERVER}")"
cp "${SCRIPT_DIR}/wrapper.sh" "${CODE_SERVER}"
chmod +x "${CODE_SERVER}"
cp "${PROJECT_ROOT}/config.sh" "$(dirname "${CODE_SERVER}")/config.sh"

# Verify the image runs correctly; restore backup on failure.
if docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" --version; then
    if [ -n "${BACKUP:-}" ] && [ -f "${BACKUP}" ]; then
        echo "${LOG_INDENT} Verification passed, removing backup: ${BACKUP}"
        rm -f "${BACKUP}"
    fi
    echo "${LOG_INDENT} Installation complete."
else
    echo "${LOG_INDENT} ERROR: Verification failed."
    if [ -n "${BACKUP:-}" ] && [ -f "${BACKUP}" ]; then
        echo "${LOG_INDENT} Restoring backup from ${BACKUP}"
        cp "${BACKUP}" "${CODE_SERVER}"
        chmod +x "${CODE_SERVER}"
    fi
    exit 1
fi