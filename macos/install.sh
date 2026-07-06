#!/bin/bash
# Install code-server Docker environment on macOS.
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
# macOS-specific differences from the Linux installer:
# - Docker Desktop for Mac uses a Linux VM; `--network host` is unsupported.
# - No `/etc/passwd` or `/etc/group` mounting (macOS uses Directory Services).
# - File permissions are handled by Docker Desktop's VirtioFS/gRPC-FUSE layer.
#
# Examples
# --------
# ```
# bash install.sh
# CODE_SERVER_VERSION=4.127.0 bash install.sh
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
log_log "${QUIET}" "Code-Server Docker Installer (macOS)"
log_log "${QUIET}" "Platform: ${RC_PLATFORM}"

# Verify container runtime (docker or finch) is installed and available.
if ! command -v "${CONTAINER_RUNTIME}" &>/dev/null; then
    echo "${LOG_INDENT} ERROR: \`${CONTAINER_RUNTIME}\` is not installed or not in PATH." >&2
    echo "${LOG_INDENT} Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/" >&2
    echo "${LOG_INDENT} Or install Finch: brew install --cask finch" >&2
    exit 1
fi

# Verify container runtime daemon is running.
if ! ${CONTAINER_RUNTIME} info &>/dev/null 2>&1; then
    echo "${LOG_INDENT} ERROR: \`${CONTAINER_RUNTIME}\` daemon is not running." >&2
    if [[ "${CONTAINER_RUNTIME}" == "finch" ]]; then
        echo "${LOG_INDENT} Run: finch vm start" >&2
    else
        echo "${LOG_INDENT} Please start Docker Desktop." >&2
    fi
    exit 1
fi
log_log "${QUIET}" "[1/4] Container runtime: $(${CONTAINER_RUNTIME} --version)"

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
log_log "${QUIET}" "Start code-server: bash ${SCRIPT_DIR}/wrapper.sh --detach"
log_log "${QUIET}" "Enter container shell: ${CONTAINER_RUNTIME} exec -it ${CONTAINER_NAME} ${DOCKER_SHELL}"
