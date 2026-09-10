#!/bin/bash
# Bootstrap code-server settings and extensions for Docker code-server on SageMaker.
#
# Defines SageMaker-specific platform hooks (`_sed_i`, `_readlink_f`,
# `_coldstart_install_extension_cmd`) and delegates to the shared coldstart
# logic in `coldstart_common.sh`.
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
# SageMaker-specific differences from the generic Linux coldstart:
# - Docker run omits `-u $(id -u):$(id -g)` (SageMaker notebooks run as
#   ec2-user; the Docker image runs as root).
# - Volume-mounts DOCKER_HOME instead of WORKSPACE for extension install
#   (SageMaker WORKSPACE points to ~/SageMaker which may differ).
#
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

# Print coldstart header.
log_log "${QUIET}" "Code-Server Coldstart (SageMaker)"

# --- Platform hooks ---

# SageMaker (Linux) GNU sed: uses `sed -i` (no backup extension argument).
_sed_i() {
    sed -i "$@"
}

# Linux readlink supports -f natively.
_readlink_f() {
    readlink -f "${1}"
}

# SageMaker Docker extension install: SELinux compat, mounts DOCKER_HOME.
# No `-u` flag (SageMaker runs as ec2-user; Docker image runs as root).
_coldstart_install_extension_cmd() {
    ${CONTAINER_RUNTIME} run --rm \
        --security-opt label:disable \
        -e "HOME=${DOCKER_HOME}" \
        -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
        -v "${DOCKER_HOME}:${DOCKER_HOME}" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        --install-extension "${1}"
}

# Source shared coldstart logic and run.
source "${PROJECT_ROOT}/coldstart_common.sh"
_coldstart_run "${QUIET}" "${PROJECT_ROOT}"
