#!/bin/bash
# Install code-server Docker environment on Linux.
#
# Builds (or loads from cache) the Docker image via `build.sh`, sets up the
# persistent home directory via `home_setup.sh`, and runs code-server
# coldstart to bootstrap settings and extensions.
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
#     Workspace root (default: `~/Workspace`).
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
log_log "${QUIET}" "Code-Server Docker Installer (Linux)"
log_log "${QUIET}" "Platform: ${RC_PLATFORM}"

# Verify Docker is installed and available on PATH.
if ! command -v docker &>/dev/null; then
    echo "${LOG_INDENT} ERROR: \`docker\` is not installed or not in PATH." >&2
    exit 1
fi
log_log "${QUIET}" "[1/4] Docker is available: $(docker --version)"

# Build (or load from cache) the Docker image.
log_log "${QUIET}" "[2/4] Building Docker image ..."
bash "${PROJECT_ROOT}/build.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG} "${CODE_SERVER_VERSION}"

# Set up persistent home directory (ssh, aws, rc files, XDG dirs).
log_log "${QUIET}" "[3/4] Setting up persistent home directory ..."
bash "${PROJECT_ROOT}/home_setup.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}

# Run code-server coldstart (settings, extensions, sync-settings).
log_log "${QUIET}" "[4/4] Running code-server coldstart ..."
bash "${SCRIPT_DIR}/code_server/coldstart.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}

# Print completion summary.
log_log "${QUIET}" "Installation complete."
log_log "${QUIET}" "Start code-server: bash ${SCRIPT_DIR}/wrapper.sh"
log_log "${QUIET}" "Enter Docker shell: docker exec -it ${CONTAINER_NAME} ${DOCKER_SHELL}"
