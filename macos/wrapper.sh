#!/bin/bash
# Launch code-server inside a Docker container on macOS.
#
# Starts the code-server Docker container with an isolated home directory,
# port mapping, and host credential sharing. Unlike the Linux wrapper, this
# uses port-forwarding instead of `--network host` (which is unsupported on
# Docker Desktop for Mac) and omits Linux-specific mounts.
#
# Args
# ----
# - `--port PORT`
#     Port to bind code-server to (default: `8080`).
# - `--detach`
#     Run the container in the background (default: foreground).
# - `$@`
#     Additional arguments forwarded to `code-server` inside the container.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# macOS-specific differences from the Linux wrapper:
# - Uses `-p` port mapping instead of `--network host` (Docker runs in a VM).
# - Omits `/etc/passwd` and `/etc/group` mounts (macOS uses Directory Services).
# - Runs as root inside the container (Docker Desktop handles file ownership
#   via its VirtioFS/gRPC-FUSE layer, `-u $(id -u):$(id -g)` causes issues).
# - Omits `--security-opt label:disable` (no SELinux on macOS).
#
# The following environment variables can override default paths:
# - `DOCKER_HOME`
#     Isolated home directory for the container.
# - `CONTAINER_NAME`
#     Docker container name (default: `"code-server-runtime"`).
#
# Examples
# --------
# ```
# bash wrapper.sh
# bash wrapper.sh --port 9090
# bash wrapper.sh --detach
# bash wrapper.sh --port 9090 --detach
# ```
set -euo pipefail

# Resolve the directory containing this script.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load shared configuration.
source "${PROJECT_ROOT}/config.sh"

# Parse wrapper-specific flags before forwarding to code-server.
PORT_DEFAULT=8080
PORT="${PORT:-${PORT_DEFAULT}}"
DETACH=0
CS_ARGS=()
while [[ $# -gt 0 ]]; do
    case "${1}" in
    --port)
        PORT="${2}"
        shift 2
        ;;
    --detach)
        DETACH=1
        shift
        ;;
    *)
        CS_ARGS+=("${1}")
        shift
        ;;
    esac
done

# Clear RC_DOCKER to prevent accidental inheritance (only docker run sets it).
unset RC_DOCKER

# Ensure XDG directories exist on the host before mounting.
mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}"

# Collect extension volume mounts from drop-in scripts.
DOCKER_EXTRA_VOLUMES=()
if [[ -d "${DOCKER_MOUNTS_DIR}" ]]; then
    for MOUNT_SCRIPT in "${DOCKER_MOUNTS_DIR}"/*.sh; do
        [[ -f "${MOUNT_SCRIPT}" ]] && source "${MOUNT_SCRIPT}"
    done
    unset MOUNT_SCRIPT
fi
EXTRA_VOLUME_FLAGS=()
for VOL in ${DOCKER_EXTRA_VOLUMES[@]+"${DOCKER_EXTRA_VOLUMES[@]}"}; do
    EXTRA_VOLUME_FLAGS+=("-v" "${VOL}")
done
unset VOL

# Build detach flag.
DETACH_FLAG=""
if [[ "${DETACH}" -eq 1 ]]; then
    DETACH_FLAG="-d"
else
    DETACH_FLAG="--rm"
fi

# Remove any stale container from a previous run.
${CONTAINER_RUNTIME} rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Default code-server arguments if none provided.
if [[ ${#CS_ARGS[@]} -eq 0 ]]; then
    CS_ARGS=("--bind-addr" "0.0.0.0:${PORT}" "--auth" "none" "${WORKSPACE}")
fi

# Build port mapping flags.
# On macOS Docker Desktop, --network host is NOT supported (Docker runs in a
# HyperKit/Apple Virtualization VM). We must use explicit -p port mappings.
PORT_FLAGS="-p 127.0.0.1:${PORT}:${PORT}"

# Map additional development ports (e.g., for Streamlit, Flask, etc.).
for DEV_PORT in $(seq 8501 8509); do
    PORT_FLAGS="${PORT_FLAGS} -p 127.0.0.1:${DEV_PORT}:${DEV_PORT}"
done

# Launch code-server with port mapping and volume mounts.
# macOS-specific notes:
# - No `--network host`: unsupported on Docker Desktop for Mac.
# - No `--security-opt label:disable`: SELinux is Linux-only.
# - No `-u $(id -u):$(id -g)`: Docker Desktop handles file ownership via
#   VirtioFS/gRPC-FUSE; running as root inside avoids permission errors.
# - No `/etc/passwd` or `/etc/group` mounts: macOS uses Directory Services.
exec ${CONTAINER_RUNTIME} run \
    --name "${CONTAINER_NAME}" \
    ${DETACH_FLAG} \
    ${PORT_FLAGS} \
    -e "HOME=${DOCKER_HOME}" \
    -e "WORKSPACE=${DOCKER_HOME}" \
    -e "DOCKER_HOME=${DOCKER_HOME}" \
    -e "RC_DOCKER=1" \
    -e "RC_PLATFORM=${RC_PLATFORM}" \
    -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
    -e "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}" \
    -e "XDG_CACHE_HOME=${XDG_CACHE_HOME}" \
    -e "XDG_STATE_HOME=${XDG_STATE_HOME}" \
    -e "SHELL=${DOCKER_SHELL}" \
    -v "${WORKSPACE}:${WORKSPACE}" \
    -v /tmp:/tmp \
    ${EXTRA_VOLUME_FLAGS[@]+"${EXTRA_VOLUME_FLAGS[@]}"} \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${CS_ARGS[@]}"
