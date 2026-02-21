#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
CODE_SERVER_VERSION="${1:-latest}"
IMAGE_NAME="code-server-sagemaker"
IMAGE_TAG="latest"

echo "Building ${IMAGE_NAME}:${IMAGE_TAG} (code-server ${CODE_SERVER_VERSION})..."

docker build \
    --build-arg "CODE_SERVER_VERSION=${CODE_SERVER_VERSION}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${SCRIPT_DIR}"

echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" --version