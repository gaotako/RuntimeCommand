#!/bin/bash
# Drop-in replacement for the code-server binary.
#
# Runs code-server inside a Docker container with an isolated home directory.
# When `jupyter-server-proxy` invokes this script, it rewrites the bind address
# from `127.0.0.1:{port}` to `0.0.0.0:{port}` so Docker port mapping works,
# while the host-side `-p` flag restricts exposure to `127.0.0.1`.
#
# Args
# ----
# - `$@`
#     Arguments forwarded to `code-server` inside the container.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# This script is copied to `${CODE_SERVER_APPLICATION}/bin/code-server` by
# `install.sh`, which also copies `config.sh` alongside it.
#
# The following environment variables can override default paths:
# - `DOCKER_HOME`
#     Isolated home directory for the container (default:
#     `/home/ec2-user/SageMaker/CodeServerDockerHome`).
set -euo pipefail

# Resolve the directory containing this script.
WRAPPER_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Load shared configuration (copied alongside this script by install.sh).
source "${WRAPPER_DIR}/config.sh"

# Clear RC_DOCKER to prevent accidental inheritance from the host environment.
# Only the explicit -e "RC_DOCKER=1" in docker run below should set it.
unset RC_DOCKER

# Resolve the passwd-home (the home directory from /etc/passwd).
# SSH and other tools use getpwuid() to resolve the home directory from
# /etc/passwd rather than the $HOME environment variable. When DOCKER_HOME
# differs from the passwd-home, we must volume-mount credential directories
# at the passwd-home path so that these tools can find them.
PASSWD_HOME="$(getent passwd "$(whoami)" 2>/dev/null | cut -d: -f6 || echo "${HOME}")"

# Persistent storage root (sibling of src/RuntimeCommand in the repo tree).
PERSISTENT_ROOT="$(cd "${WRAPPER_DIR}/../../../.." && pwd)"

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

# Rewrite bind-addr arguments for container networking.
# `jupyter-server-proxy` passes `--bind-addr 127.0.0.1:{port}`, but code-server
# inside the container must bind to `0.0.0.0` for Docker port mapping to reach
# it. The extracted port is used for the host-side `-p` flag.
PORT=""
REWRITTEN_ARGS=()
for arg in "${@}"; do
    if [[ "${arg}" =~ ^([0-9.]+):([0-9]+)$ ]]; then
        PORT="${BASH_REMATCH[2]}"
        REWRITTEN_ARGS+=("0.0.0.0:${PORT}")
    else
        REWRITTEN_ARGS+=("${arg}")
    fi
done

# Clear the Jupyter restart hint flag (set by lifecycle scripts).
# Opening code-server means Jupyter has been restarted successfully.
rm -f "${APP_DATA_HOME}/.jupyter_restart_needed"

# Build port-mapping flags (SageMaker requires bridge networking).
PORT_FLAGS=""
if [[ -n "${PORT}" ]]; then
    PORT_FLAGS="-p 127.0.0.1:${PORT}:${PORT}"
fi
for DEV_PORT in $(seq 8501 8509); do
    PORT_FLAGS="${PORT_FLAGS} -p 127.0.0.1:${DEV_PORT}:${DEV_PORT}"
done

# Append the workspace folder so code-server opens in a user directory
# (prevents "can't download to this folder since it contains system files").
REWRITTEN_ARGS+=("${WORKSPACE}")

# Remove any stale container from a previous run.
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Launch code-server with bridge networking (SELinux compat, no -u on SageMaker).
exec docker run --rm \
    --name "${CONTAINER_NAME}" \
    --security-opt label:disable \
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
    -e "TERM=${TERM:-xterm}" \
    -e "SHELL=${DOCKER_SHELL}" \
    -v "${WORKSPACE}:${WORKSPACE}" \
    -v /opt/ml:/opt/ml:ro \
    -v /tmp:/tmp \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    ${PASSWD_HOME_VOLUME_FLAGS[@]+"${PASSWD_HOME_VOLUME_FLAGS[@]}"} \
    ${EXTRA_VOLUME_FLAGS[@]+"${EXTRA_VOLUME_FLAGS[@]}"} \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${REWRITTEN_ARGS[@]}"
