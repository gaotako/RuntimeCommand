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
# - $@
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

# Resolve the directory containing this script.
WRAPPER_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Load shared configuration (copied alongside this script by install.sh).
source "${WRAPPER_DIR}/config.sh"

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
if [ -n "${PORT}" ]; then
    PORT_FLAGS="-p 127.0.0.1:${PORT}:${PORT}"
fi

# Remove any stale container from a previous run.
docker rm -f code-server-sagemaker >/dev/null 2>&1 || true

# Launch code-server inside the container.
# `--security-opt label:disable` is set for SELinux compatibility.
# No `-u` flag because Docker user namespace remapping on SageMaker maps
# host uid 1000 to container uid 0.
exec docker run --rm \
    --name code-server-sagemaker \
    --security-opt label:disable \
    ${PORT_FLAGS} \
    -e "HOME=${DOCKER_HOME}" \
    -e "WORKSPACE=${DOCKER_HOME}" \
    -e "XDG_DATA_HOME=${XDG_DATA_HOME}" \
    -e "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}" \
    -e "XDG_CACHE_HOME=${XDG_CACHE_HOME}" \
    -e "XDG_STATE_HOME=${XDG_STATE_HOME}" \
    -e "SHELL=/bin/bash" \
    -v "${DOCKER_HOME}:${DOCKER_HOME}" \
    -v /opt/ml:/opt/ml:ro \
    -v /tmp:/tmp \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${REWRITTEN_ARGS[@]}"