#!/bin/bash
# Build (or load from cache) the code-server Docker image.
#
# On first run, builds the image from the Dockerfile and saves it to persistent
# storage under `~/SageMaker/` so it survives SageMaker notebook restarts. On
# subsequent runs, loads the cached image instead of rebuilding.
#
# Args
# ----
# - CODE_SERVER_VERSION
#     code-server version to install (default: `"latest"`).
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
# The following environment variables can override default behaviour:
# - `DOCKER_IMAGE_DIR`
#     Directory for persistent image storage.
# - `FORCE_BUILD`
#     Set to `"1"` to skip cache and force a fresh build.
#
# Examples
# --------
# ```
# bash build.sh
# bash build.sh 4.109.2
# FORCE_BUILD=1 bash build.sh 4.109.2
# bash build.sh --log-depth 2 4.109.2
# ```
set -euo pipefail

# Resolve the directory containing this script.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source shared libraries and defaults.
source "${SCRIPT_DIR}/shutils/argparse.sh"
source "${SCRIPT_DIR}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH via --log-depth).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (respects values already set by argparse).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Override CODE_SERVER_VERSION from positional argument if provided.
CODE_SERVER_VERSION="${1:-${CODE_SERVER_VERSION}}"

# Pre-build checks: verify all required tools and files are available.
# Docker is needed for image build; pip and python3 are needed by
# setup_jupyter.sh to install the JupyterLab extension; curl is needed
# by mise.sh for downloading the mise binary.
BUILD_CHECK_FAILED=0
for required_cmd in docker curl pip python3; do
    if ! command -v "${required_cmd}" &>/dev/null; then
        echo "${LOG_INDENT} ERROR: Required command '${required_cmd}' is not installed or not in PATH."
        BUILD_CHECK_FAILED=1
    fi
done
for required_file in Dockerfile entrypoint.sh; do
    if [[ ! -f "${SCRIPT_DIR}/${required_file}" ]]; then
        echo "${LOG_INDENT} ERROR: Required file '${required_file}' not found in ${SCRIPT_DIR}."
        BUILD_CHECK_FAILED=1
    fi
done
if [[ "${BUILD_CHECK_FAILED}" -eq 1 ]]; then
    echo "${LOG_INDENT} Pre-build checks failed. Please install missing dependencies."
    exit 1
fi
echo "${LOG_INDENT} Pre-build checks passed."

# Persistent image file path.
DOCKER_IMAGE_FILE="${DOCKER_IMAGE_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar"

# Attempt to load a previously saved image from persistent storage.
# Skipped when `FORCE_BUILD=1` or when no cached file exists.
if [ -f "${DOCKER_IMAGE_FILE}" ] && [ "${FORCE_BUILD:-}" != "1" ]; then
    echo "${LOG_INDENT} Found saved image at ${DOCKER_IMAGE_FILE}, loading ..."
    if docker load -i "${DOCKER_IMAGE_FILE}"; then
        echo "${LOG_INDENT} Image loaded from persistent storage."
        docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" --version
        exit 0
    else
        echo "${LOG_INDENT} WARNING: Failed to load saved image, will rebuild."
    fi
fi

# Build the Docker image from the Dockerfile in this directory.
echo "${LOG_INDENT} Building ${IMAGE_NAME}:${IMAGE_TAG} (code-server ${CODE_SERVER_VERSION}) ..."
docker build \
    --build-arg "CODE_SERVER_VERSION=${CODE_SERVER_VERSION}" \
    --build-arg "DOCKER_SHELL=${DOCKER_SHELL}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${SCRIPT_DIR}"

# Verify the newly built image starts correctly.
echo "${LOG_INDENT} Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" --version

# Save the image to persistent storage so it survives SageMaker restarts.
echo "${LOG_INDENT} Saving image to ${DOCKER_IMAGE_FILE} ..."
mkdir -p "${DOCKER_IMAGE_DIR}"
docker save -o "${DOCKER_IMAGE_FILE}" "${IMAGE_NAME}:${IMAGE_TAG}"
echo "${LOG_INDENT} Image saved to persistent storage."
