#!/bin/bash
# Bootstrap code-server settings and extensions for Docker code-server on macOS.
#
# Defines macOS-specific platform hooks (`_sed_i`, `_readlink_f`,
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
# macOS-specific differences from the Linux coldstart:
# - Uses `sed -i ''` (BSD sed) instead of `sed -i` (GNU sed).
# - Uses a portable `readlink` alternative (Python/perl fallback) since
#   macOS BSD readlink does not support `-f`.
# - Docker run omits `-u $(id -u):$(id -g)` (Docker Desktop handles ownership).
# - No `--security-opt label:disable` (no SELinux on macOS).
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
MACOS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${MACOS_ROOT}/.." && pwd)"

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
log_log "${QUIET}" "Code-Server Coldstart (macOS)"

# --- Platform hooks ---

# macOS BSD sed: requires `sed -i ''` (empty backup extension).
_sed_i() {
    sed -i '' "$@"
}

# Portable readlink -f replacement for macOS (BSD readlink lacks -f).
_readlink_f() {
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "${1}" 2>/dev/null \
        || perl -MCwd -e 'print Cwd::realpath($ARGV[0]),"\n"' "${1}" 2>/dev/null \
        || echo "${1}"
}

# macOS Docker extension install: no -u flag (Docker Desktop handles ownership),
# no --security-opt (no SELinux on macOS).
_coldstart_install_extension_cmd() {
    ${CONTAINER_RUNTIME} run --rm \
        -e "HOME=${DOCKER_HOME}" \
        -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
        -v "${WORKSPACE}:${WORKSPACE}" \
        "${IMAGE_NAME}:${IMAGE_TAG}" \
        --install-extension "${1}"
}

# Source shared coldstart logic and run.
source "${PROJECT_ROOT}/coldstart_common.sh"
_coldstart_run "${QUIET}" "${PROJECT_ROOT}"
