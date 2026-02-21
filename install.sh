#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# RuntimeCommand paths (defaults match rc.sh)
HOME="${HOME:-/home/ec2-user}"
WORKSPACE="${WORKSPACE:-${HOME}/SageMaker}"
APP_ROOT="${APP_ROOT:-${WORKSPACE}/Application}"
APP_DATA_HOME="${APP_DATA_HOME:-${APP_ROOT}/data}"
CODE_SERVER_APPLICATION="${CODE_SERVER_APPLICATION:-${APP_DATA_HOME}/cs}"
CODE_SERVER="${CODE_SERVER:-${CODE_SERVER_APPLICATION}/bin/code-server}"

echo "=== Code-Server Docker Installer ==="
echo "Target: ${CODE_SERVER}"

# 1. Check Docker is available
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed or not in PATH."
    exit 1
fi
echo "[1/4] Docker is available: $(docker --version)"

# 2. Build the Docker image
echo "[2/4] Building Docker image..."
bash "${SCRIPT_DIR}/build.sh" "${CODE_SERVER_VERSION:-latest}"

# 3. Back up existing binary if present
if [ -f "${CODE_SERVER}" ]; then
    BACKUP="${CODE_SERVER}.bak.$(date +%Y%m%d%H%M%S)"
    echo "[3/4] Backing up existing binary to ${BACKUP}"
    cp "${CODE_SERVER}" "${BACKUP}"
else
    echo "[3/4] No existing binary found, skipping backup."
fi

# 4. Install wrapper script and verify
echo "[4/4] Installing wrapper script to ${CODE_SERVER}"
mkdir -p "$(dirname "${CODE_SERVER}")"
cp "${SCRIPT_DIR}/wrapper.sh" "${CODE_SERVER}"
chmod +x "${CODE_SERVER}"

if docker run --rm code-server-sagemaker:latest --version; then
    if [ -n "${BACKUP:-}" ] && [ -f "${BACKUP}" ]; then
        echo "Verification passed, removing backup: ${BACKUP}"
        rm -f "${BACKUP}"
    fi
    echo "=== Installation complete ==="
else
    echo "ERROR: Verification failed."
    if [ -n "${BACKUP:-}" ] && [ -f "${BACKUP}" ]; then
        echo "Restoring backup from ${BACKUP}"
        cp "${BACKUP}" "${CODE_SERVER}"
        chmod +x "${CODE_SERVER}"
    fi
    exit 1
fi