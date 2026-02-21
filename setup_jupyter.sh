#!/bin/bash
set -euo pipefail

# RuntimeCommand paths (defaults match rc.sh)
HOME="${HOME:-/home/ec2-user}"
WORKSPACE="${WORKSPACE:-${HOME}/SageMaker}"
APP_ROOT="${APP_ROOT:-${WORKSPACE}/Application}"
APP_DATA_HOME="${APP_DATA_HOME:-${APP_ROOT}/data}"
CODE_SERVER_APPLICATION="${CODE_SERVER_APPLICATION:-${APP_DATA_HOME}/cs}"
CODE_SERVER="${CODE_SERVER:-${CODE_SERVER_APPLICATION}/bin/code-server}"

JUPYTER_CONFIG="${JUPYTER_CONFIG:-${HOME}/.jupyter/jupyter_notebook_config.py}"
LAUNCHER_ENTRY_TITLE="Code Server"
PROXY_PATH="codeserver"
PROXY_TIMEOUT=120
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
ICON_PATH="${CODE_SERVER_APPLICATION}/icons/codeserver.svg"
EXTENSION_DIR="${SCRIPT_DIR}/sagemaker_jproxy_launcher_ext"

echo "=== Code-Server Jupyter Registration ==="
echo "Target: ${CODE_SERVER}"
echo "Config: ${JUPYTER_CONFIG}"

# 1. Register code-server with jupyter-server-proxy
if grep -q "${CODE_SERVER_APPLICATION}/bin/code-server" "${JUPYTER_CONFIG}" 2>/dev/null; then
    echo "[1/3] Server-proxy configuration already exists. Updating timeout to ${PROXY_TIMEOUT}s..."
    sed -i "/'${PROXY_PATH}':/,/^    }/s/'timeout': [0-9]*/'timeout': ${PROXY_TIMEOUT}/" "${JUPYTER_CONFIG}"
else
    echo "[1/3] Adding server-proxy configuration to ${JUPYTER_CONFIG}"
    cat >>"${JUPYTER_CONFIG}" <<EOC
c.ServerProxy.servers = {
    "${PROXY_PATH}": {
        "launcher_entry": {
            "enabled": True,
            "title": "${LAUNCHER_ENTRY_TITLE}",
            "icon_path": "${ICON_PATH}",
        },
        "command": [
            "${CODE_SERVER_APPLICATION}/bin/code-server",
            "--auth",
            "none",
            "--disable-telemetry",
            "--bind-addr",
            "127.0.0.1:{port}",
        ],
        "environment": {
            "SHELL": "/bin/bash",
        },
        "absolute_url": False,
        "timeout": ${PROXY_TIMEOUT},
    }
}
EOC
fi

# 2. Install icon and JupyterLab extension
echo "[2/3] Installing icon and JupyterLab extension..."

mkdir -p "$(dirname "${ICON_PATH}")"
cp "${EXTENSION_DIR}/style/icons/codeserver.svg" "${ICON_PATH}"

sudo -u ec2-user -i <<EOF
source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv

pip install "${EXTENSION_DIR}"
jupyter labextension disable jupyterlab-server-proxy

conda deactivate
EOF

# 3. Restart Jupyter server
echo "[3/3] Restarting Jupyter server..."
if [[ -f /home/ec2-user/bin/dockerd-rootless.sh ]]; then
    echo "Running in rootless mode; please restart Jupyter from 'File' > 'Shut Down' and re-open."
else
    sudo systemctl restart jupyter-server
fi

echo "=== Jupyter registration complete ==="