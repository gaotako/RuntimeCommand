#!/bin/bash
# Launch code-server inside a Docker container on Linux.
#
# Starts the code-server Docker container with an isolated home directory,
# port mapping, and host credential sharing. Unlike the SageMaker wrapper,
# this is invoked directly by the user (not via jupyter-server-proxy).
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

# Resolve the passwd-home (the home directory from /etc/passwd).
# SSH and other tools use getpwuid() to resolve the home directory from
# /etc/passwd rather than the $HOME environment variable. When DOCKER_HOME
# differs from the passwd-home, we must volume-mount credential directories
# at the passwd-home path so that these tools can find them.
PASSWD_HOME="$(getent passwd "$(whoami)" 2>/dev/null | cut -d: -f6 || echo "${HOME}")"

# Persistent storage root (same as home_setup.sh uses).
PERSISTENT_ROOT="$(cd "${PROJECT_ROOT}/../.." && pwd)"

# Resolve credential directories by following symlinks from DOCKER_HOME.
# home_setup.sh creates symlinks (e.g., DOCKER_HOME/.ssh → PERSISTENT_ROOT/ssh).
# Resolving via symlinks is more robust than computing PERSISTENT_ROOT from the
# script location, which can fail if the wrapper is installed at a non-standard
# depth relative to the persistent storage.
_resolve_cred_dir() {
    local LINK="${DOCKER_HOME}/${1}"
    if [[ -L "${LINK}" ]]; then
        readlink -f "${LINK}"
    elif [[ -L "${HOME}/${1}" ]]; then
        readlink -f "${HOME}/${1}"
    elif [[ -d "${PERSISTENT_ROOT}/${2}" ]]; then
        echo "${PERSISTENT_ROOT}/${2}"
    else
        echo ""
    fi
}

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

# Build passwd-home credential volume mounts.
# When DOCKER_HOME differs from the passwd-home, mount the persistent
# credential directories at the passwd-home path so tools using getpwuid()
# (like SSH) can find them.
PASSWD_HOME_VOLUME_FLAGS=()
if [[ "${PASSWD_HOME}" != "${DOCKER_HOME}" && "${PASSWD_HOME}" != "${WORKSPACE}" ]]; then
    # Resolve credential dirs via symlinks first, falling back to PERSISTENT_ROOT.
    SSH_PERSISTENT="$(_resolve_cred_dir ".ssh" "ssh")"
    AWS_PERSISTENT="$(_resolve_cred_dir ".aws" "aws")"
    MIDWAY_PERSISTENT="$(_resolve_cred_dir ".midway" "midway")"
    if [[ -n "${SSH_PERSISTENT}" && -d "${SSH_PERSISTENT}" ]]; then
        PASSWD_HOME_VOLUME_FLAGS+=("-v" "${SSH_PERSISTENT}:${PASSWD_HOME}/.ssh")
    fi
    if [[ -n "${AWS_PERSISTENT}" && -d "${AWS_PERSISTENT}" ]]; then
        PASSWD_HOME_VOLUME_FLAGS+=("-v" "${AWS_PERSISTENT}:${PASSWD_HOME}/.aws")
    fi
    if [[ -n "${MIDWAY_PERSISTENT}" && -d "${MIDWAY_PERSISTENT}" ]]; then
        PASSWD_HOME_VOLUME_FLAGS+=("-v" "${MIDWAY_PERSISTENT}:${PASSWD_HOME}/.midway")
    fi
fi

# Build detach and restart flags. A detached container gets a restart policy so
# the Docker daemon resurrects it after a host reboot or daemon restart (the
# cloud desktop reboots periodically to apply system updates). Foreground runs
# use --rm for cleanup, which is incompatible with --restart, so they get no
# restart policy.
DETACH_FLAG=""
RESTART_FLAG=""
if [[ "${DETACH}" -eq 1 ]]; then
    DETACH_FLAG="-d"
    RESTART_FLAG="--restart unless-stopped"
else
    DETACH_FLAG="--rm"
fi

# Remove any stale container from a previous run.
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Default code-server arguments if none provided.
if [[ ${#CS_ARGS[@]} -eq 0 ]]; then
    CS_ARGS=("--bind-addr" "0.0.0.0:${PORT}" "--auth" "none" "${WORKSPACE}")
fi

# Launch code-server with host networking, SELinux compat, and volume mounts.
exec docker run \
    --name "${CONTAINER_NAME}" \
    ${DETACH_FLAG} \
    ${RESTART_FLAG} \
    --network host \
    --security-opt label:disable \
    -u "$(id -u):$(id -g)" \
    -e "HOME=${DOCKER_HOME}" \
    -e "WORKSPACE=${DOCKER_HOME}" \
    -e "DOCKER_HOME=${DOCKER_HOME}" \
    -e "RC_DOCKER=1" \
    -e "RC_PLATFORM=${RC_PLATFORM}" \
    -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
    -e "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}" \
    -e "XDG_CACHE_HOME=${XDG_CACHE_HOME}" \
    -e "XDG_STATE_HOME=${XDG_STATE_HOME}" \
    -e "TERM=${TERM:-xterm}" \
    -e "SHELL=${DOCKER_SHELL}" \
    -v "${WORKSPACE}:${WORKSPACE}" \
    -v /tmp:/tmp \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    ${PASSWD_HOME_VOLUME_FLAGS[@]+"${PASSWD_HOME_VOLUME_FLAGS[@]}"} \
    ${EXTRA_VOLUME_FLAGS[@]+"${EXTRA_VOLUME_FLAGS[@]}"} \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${CS_ARGS[@]}"
