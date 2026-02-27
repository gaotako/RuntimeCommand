#!/bin/bash
# Build (or load from cache) the code-server Docker image.
#
# On first run, builds the image from the Dockerfile and saves it to persistent
# storage under `~/SageMaker/` so it survives SageMaker notebook restarts. On
# subsequent runs, loads the cached image instead of rebuilding.
#
# Args
# ----
# - `CODE_SERVER_VERSION`
#     code-server version to install (default: `"latest"`).
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
# bash build.sh --quiet
# ```
set -euo pipefail

# Resolve the directory containing this script.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source shared libraries and defaults.
source "${SCRIPT_DIR}/shutils/argparse.sh"
source "${SCRIPT_DIR}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH, QUIET via --log-depth, --quiet).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (respects values already set by argparse).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve quiet flag from argparse (--quiet sets QUIET=1).
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# Override CODE_SERVER_VERSION from positional argument if provided.
if [[ ${#POSITIONAL_ARGS[@]} -gt 0 ]]; then
    CODE_SERVER_VERSION="${POSITIONAL_ARGS[0]}"
fi

# Pre-build checks: verify all required tools and files are available.
# Docker is needed for image build.
BUILD_CHECK_FAILED=0
for REQUIRED_CMD in docker; do
    if ! command -v "${REQUIRED_CMD}" &>/dev/null; then
        echo "${LOG_INDENT} ERROR: Required command \`${REQUIRED_CMD}\` is not installed or not in PATH." >&2
        BUILD_CHECK_FAILED=1
    fi
done
for REQUIRED_FILE in Dockerfile entrypoint.sh; do
    if [[ ! -f "${SCRIPT_DIR}/${REQUIRED_FILE}" ]]; then
        echo "${LOG_INDENT} ERROR: Required file \`${REQUIRED_FILE}\` not found in \`${SCRIPT_DIR}\`." >&2
        BUILD_CHECK_FAILED=1
    fi
done
if [[ "${BUILD_CHECK_FAILED}" -eq 1 ]]; then
    echo "${LOG_INDENT} Pre-build checks failed. Please install missing dependencies." >&2
    exit 1
fi
log_log "${QUIET}" "Pre-build checks passed."

# Persistent image file path.
DOCKER_IMAGE_FILE="${DOCKER_IMAGE_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar"

# Attempt to load a previously saved image from persistent storage.
# Skipped when `FORCE_BUILD=1` or when no cached file exists.
# Retries up to 5 times with exponential backoff to handle transient
# Docker daemon instability during SageMaker startup. If all load attempts
# fail, falls through to a full Docker build (which retries separately).
if [[ -f "${DOCKER_IMAGE_FILE}" ]] && [[ "${FORCE_BUILD:-}" != "1" ]]; then
    log_log "${QUIET}" "Found saved image at ${DOCKER_IMAGE_FILE}, loading ..."
    LOAD_ATTEMPTS=5
    LOAD_WAIT_TIMEOUT=60
    LOAD_SUCCESS=0
    for LOAD_TRY in $(seq 1 "${LOAD_ATTEMPTS}"); do
        if docker load -i "${DOCKER_IMAGE_FILE}"; then
            LOAD_SUCCESS=1
            break
        fi

        if [[ "${LOAD_TRY}" -eq "${LOAD_ATTEMPTS}" ]]; then
            echo "${LOG_INDENT} WARNING: Failed to load saved image after ${LOAD_ATTEMPTS} attempts. Will rebuild." >&2
            break
        fi

        echo "${LOG_INDENT} WARNING: Load attempt ${LOAD_TRY}/${LOAD_ATTEMPTS} failed. Waiting for \`docker\` daemon (timeout: ${LOAD_WAIT_TIMEOUT}s) ..." >&2

        DOCKER_WAIT=0
        while ! docker info &>/dev/null; do
            sleep 5
            DOCKER_WAIT=$((DOCKER_WAIT + 5))
            if [[ "${DOCKER_WAIT}" -ge "${LOAD_WAIT_TIMEOUT}" ]]; then
                echo "${LOG_INDENT} WARNING: \`docker\` daemon did not recover within ${LOAD_WAIT_TIMEOUT} seconds. Will retry load ..." >&2
                break
            fi
        done

        LOAD_WAIT_TIMEOUT=$((LOAD_WAIT_TIMEOUT * 2))
        sleep 5
    done

    if [[ "${LOAD_SUCCESS}" -eq 1 ]]; then
        log_log "${QUIET}" "Image loaded from persistent storage."
        docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" --version
        exit 0
    fi
fi

# Build the Docker image from the Dockerfile in this directory.
# Retries up to 5 times to handle transient Docker daemon instability
# (e.g., `rpc error: EOF` during SageMaker notebook initialization).
# Docker caches completed layers, so retries resume from the last success.
log_log "${QUIET}" "Building ${IMAGE_NAME}:${IMAGE_TAG} (code-server ${CODE_SERVER_VERSION}) ..."
BUILD_ATTEMPTS=5
DOCKER_WAIT_TIMEOUT=60
for BUILD_TRY in $(seq 1 "${BUILD_ATTEMPTS}"); do
    if docker build \
        --build-arg "CODE_SERVER_VERSION=${CODE_SERVER_VERSION}" \
        --build-arg "DOCKER_SHELL=${DOCKER_SHELL}" \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        "${SCRIPT_DIR}"; then
        break
    fi

    if [[ "${BUILD_TRY}" -eq "${BUILD_ATTEMPTS}" ]]; then
        echo "${LOG_INDENT} ERROR: Docker build failed after ${BUILD_ATTEMPTS} attempts." >&2
        exit 1
    fi

    echo "${LOG_INDENT} WARNING: Docker build attempt ${BUILD_TRY}/${BUILD_ATTEMPTS} failed. Waiting for \`docker\` daemon (timeout: ${DOCKER_WAIT_TIMEOUT}s) ..." >&2

    # Wait for Docker daemon to recover with exponential backoff timeout.
    # SageMaker may restart the Docker daemon during lifecycle transitions,
    # which can take several minutes. If wait times out, the loop continues
    # to the next retry attempt with a doubled timeout.
    DOCKER_WAIT=0
    while ! docker info &>/dev/null; do
        sleep 5
        DOCKER_WAIT=$((DOCKER_WAIT + 5))
        if [[ "${DOCKER_WAIT}" -ge "${DOCKER_WAIT_TIMEOUT}" ]]; then
            echo "${LOG_INDENT} WARNING: \`docker\` daemon did not recover within ${DOCKER_WAIT_TIMEOUT} seconds. Will retry build ..." >&2
            break
        fi
    done

    # Double timeout for next retry.
    DOCKER_WAIT_TIMEOUT=$((DOCKER_WAIT_TIMEOUT * 2))

    # Extra stabilization wait after daemon responds.
    sleep 5
done

# Verify the newly built image starts correctly.
log_log "${QUIET}" "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" --version

# Save the image to persistent storage so it survives SageMaker restarts.
log_log "${QUIET}" "Saving image to ${DOCKER_IMAGE_FILE} ..."
mkdir -p "${DOCKER_IMAGE_DIR}"
docker save -o "${DOCKER_IMAGE_FILE}" "${IMAGE_NAME}:${IMAGE_TAG}"
log_log "${QUIET}" "Image saved to persistent storage."