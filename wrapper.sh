#!/bin/bash
# Drop-in replacement for the code-server binary.
# Runs code-server inside a Docker container with an isolated home directory.

IMAGE_NAME="code-server-sagemaker"
IMAGE_TAG="latest"

# Docker-specific home (isolated from host to avoid permission issues)
DOCKER_HOME="/home/ec2-user/SageMaker/CodeServerDockerHome"
XDG_ROOT="${DOCKER_HOME}/CrossDesktopGroup"
XDG_DATA_HOME="${XDG_ROOT}/local/share"
XDG_CONFIG_HOME="${XDG_ROOT}/config"
XDG_CACHE_HOME="${XDG_ROOT}/cache"
XDG_STATE_HOME="${XDG_ROOT}/local/state"

mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}"

# Rewrite bind-addr for container networking.
# jupyter-server-proxy passes --bind-addr 127.0.0.1:{port}, but code-server inside
# the container must bind to 0.0.0.0 for Docker port mapping to reach it.
# The host-side -p flag restricts exposure to 127.0.0.1.
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

PORT_FLAGS=""
if [ -n "${PORT}" ]; then
    PORT_FLAGS="-p 127.0.0.1:${PORT}:${PORT}"
fi

docker rm -f code-server-sagemaker >/dev/null 2>&1 || true

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