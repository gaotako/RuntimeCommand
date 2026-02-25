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
# bash install.sh --quiet
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH, QUIET via --log-depth, --quiet).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (respects values already set by argparse).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve quiet flag from argparse (--quiet sets QUIET=1).
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# Build quiet flag for sub-scripts.
QUIET_FLAG=""
[[ "${QUIET}" -eq 1 ]] && QUIET_FLAG="--quiet"

# Print installation header.
log_log "${QUIET}" "Code-Server Docker Installer"
log_log "${QUIET}" "Target: ${CODE_SERVER}"

# Verify Docker is installed and available on PATH.
if ! command -v docker &>/dev/null; then
    echo "${LOG_INDENT} ERROR: \`docker\` is not installed or not in PATH." >&2
    exit 1
fi
log_log "${QUIET}" "[1/4] Docker is available: $(docker --version)"

# Build (or load from cache) the Docker image.
log_log "${QUIET}" "[2/4] Building Docker image ..."
bash "${PROJECT_ROOT}/build.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG} "${CODE_SERVER_VERSION}"

# Back up the existing binary if one is already installed.
if [[ -f "${CODE_SERVER}" ]]; then
    BACKUP="${CODE_SERVER}.bak.$(date +%Y%m%d%H%M%S)"
    log_log "${QUIET}" "[3/4] Backing up existing binary to ${BACKUP}"
    cp "${CODE_SERVER}" "${BACKUP}"
else
    log_log "${QUIET}" "[3/4] No existing binary found, skipping backup."
fi

# Install the wrapper script and config alongside it.
log_log "${QUIET}" "[4/4] Installing wrapper script to ${CODE_SERVER}"
mkdir -p "$(dirname "${CODE_SERVER}")"
cp "${SCRIPT_DIR}/wrapper.sh" "${CODE_SERVER}"
chmod +x "${CODE_SERVER}"
cp "${PROJECT_ROOT}/config.sh" "$(dirname "${CODE_SERVER}")/config.sh"

# Verify the image runs correctly; restore backup on failure.
if docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" --version; then
    if [[ -n "${BACKUP:-}" ]] && [[ -f "${BACKUP}" ]]; then
        log_log "${QUIET}" "Verification passed, removing backup: ${BACKUP}"
        rm -f "${BACKUP}"
    fi
    log_log "${QUIET}" "Installation complete."
else
    echo "${LOG_INDENT} ERROR: Verification failed." >&2
    if [[ -n "${BACKUP:-}" ]] && [[ -f "${BACKUP}" ]]; then
        echo "${LOG_INDENT} Restoring backup from \`${BACKUP}\`" >&2
        cp "${BACKUP}" "${CODE_SERVER}"
        chmod +x "${CODE_SERVER}"
    fi
    exit 1
fi