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

# Ensure XDG directories exist on the host before mounting.
mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}"

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

# Build the port-mapping flag if a port was detected.
PORT_FLAGS=""
if [[ -n "${PORT}" ]]; then
    PORT_FLAGS="-p 127.0.0.1:${PORT}:${PORT}"
fi

# Map additional ports for development servers (Streamlit: 8501-8509).
for DEV_PORT in $(seq 8501 8509); do
    PORT_FLAGS="${PORT_FLAGS} -p 127.0.0.1:${DEV_PORT}:${DEV_PORT}"
done

# Clear the Jupyter restart hint flag (set by lifecycle scripts).
# Opening code-server means Jupyter has been restarted successfully.
rm -f "${APP_DATA_HOME}/.jupyter_restart_needed"

# Remove any stale container from a previous run.
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Mount host tools under /host/* (lower priority than Docker binaries).
HOST_TOOL_FLAGS=""
HOST_TOOL_PATH=""
for HOST_DIR in /usr/bin /lib64 /apollo/env; do
    if [[ -d "${HOST_DIR}" ]]; then
        HOST_TOOL_FLAGS="${HOST_TOOL_FLAGS} -v ${HOST_DIR}:/host${HOST_DIR}:ro"
        HOST_TOOL_PATH="${HOST_TOOL_PATH}:/host${HOST_DIR}"
    fi
done
for HOST_FILE in /etc/krb5.conf; do
    if [[ -f "${HOST_FILE}" ]]; then
        HOST_TOOL_FLAGS="${HOST_TOOL_FLAGS} -v ${HOST_FILE}:${HOST_FILE}:ro"
    fi
done
for HOST_DIR in /etc/krb5.conf.d; do
    if [[ -d "${HOST_DIR}" ]]; then
        HOST_TOOL_FLAGS="${HOST_TOOL_FLAGS} -v ${HOST_DIR}:${HOST_DIR}:ro"
    fi
done

# Launch code-server inside the container (SELinux compat, no -u on SageMaker).
exec docker run --rm \
    --name "${CONTAINER_NAME}" \
    --security-opt label:disable \
    ${PORT_FLAGS} \
    -e "HOME=${DOCKER_HOME}" \
    -e "WORKSPACE=${DOCKER_HOME}" \
    -e "RC_DOCKER=1" \
    -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
    -e "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}" \
    -e "XDG_CACHE_HOME=${XDG_CACHE_HOME}" \
    -e "XDG_STATE_HOME=${XDG_STATE_HOME}" \
    -e "SHELL=${DOCKER_SHELL}" \
    -e "LD_LIBRARY_PATH=/host/lib64" \
    -e "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${HOST_TOOL_PATH}" \
    -v "${WORKSPACE}:${WORKSPACE}" \
    -v /opt/ml:/opt/ml:ro \
    -v /tmp:/tmp \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    ${HOST_TOOL_FLAGS} \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${REWRITTEN_ARGS[@]}"
