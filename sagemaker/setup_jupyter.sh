#!/bin/bash
# Register code-server with JupyterLab as a server-proxy entry.
#
# Adds `c.ServerProxy.servers` configuration to `jupyter_notebook_config.py`,
# installs the `sagemaker_jproxy_launcher_ext` JupyterLab extension and the
# launcher icon, then restarts the Jupyter server if it is already running.
#
# Args
# ----
# - --log-depth LOG_DEPTH
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - --quiet
#     When set, suppresses step-by-step log output.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# The following environment variables can override default paths:
# - `HOME`
#     User home directory.
# - `WORKSPACE`
#     SageMaker workspace root.
# - `APP_ROOT`
#     Application root directory.
# - `APP_DATA_HOME`
#     Application data directory.
# - `CODE_SERVER_APPLICATION`
#     code-server application directory.
# - `CODE_SERVER`
#     Path to the code-server binary / wrapper.
# - `JUPYTER_CONFIG`
#     Path to the Jupyter notebook configuration file.
#
# Examples
# --------
# ```
# bash setup_jupyter.sh
# bash setup_jupyter.sh --log-depth 2
# bash setup_jupyter.sh --quiet
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH, QUIET via --log-depth, --quiet).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (respects values already set by argparse).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve quiet flag from argparse (--quiet sets QUIET=1).
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# Server-proxy registration constants.
LAUNCHER_ENTRY_TITLE="Code Server"
PROXY_PATH="codeserver"
PROXY_TIMEOUT=120
ICON_PATH="${CODE_SERVER_APPLICATION}/icons/codeserver.svg"
EXTENSION_DIR="${SCRIPT_DIR}/sagemaker_jproxy_launcher_ext"

# Print registration header.
log_log "${QUIET}" "Code-Server Jupyter Registration"
log_log "${QUIET}" "Target: ${CODE_SERVER}"
log_log "${QUIET}" "Config: ${JUPYTER_CONFIG}"

# Add or update the `c.ServerProxy.servers` block in the Jupyter config.
# If the block already exists, only the timeout value is patched.
if grep -q "${CODE_SERVER_APPLICATION}/bin/code-server" "${JUPYTER_CONFIG}" 2>/dev/null; then
    log_log "${QUIET}" "[1/3] Server-proxy configuration already exists. Updating timeout to ${PROXY_TIMEOUT}s ..."
    sed -i "/'${PROXY_PATH}':/,/^    }/s/'timeout': [0-9]*/'timeout': ${PROXY_TIMEOUT}/" "${JUPYTER_CONFIG}"
else
    log_log "${QUIET}" "[1/3] Adding server-proxy configuration to ${JUPYTER_CONFIG}"
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

# Install the launcher icon and the JupyterLab extension into JupyterSystemEnv.
log_log "${QUIET}" "[2/3] Installing icon and JupyterLab extension ..."
mkdir -p "$(dirname "${ICON_PATH}")"
cp "${EXTENSION_DIR}/style/icons/codeserver.svg" "${ICON_PATH}"
sudo -u ec2-user -i <<EOF
source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv

pip install jupyter-packaging
pip install "${EXTENSION_DIR}"
jupyter labextension disable jupyterlab-server-proxy

conda deactivate
EOF

# Restart Jupyter server so the new proxy entry takes effect.
# Skipped when Jupyter is not yet running (e.g. during lifecycle config).
log_log "${QUIET}" "[3/3] Restarting Jupyter server ..."
if [[ -f /home/ec2-user/bin/dockerd-rootless.sh ]]; then
    log_log "${QUIET}" "Running in rootless mode; please restart Jupyter from 'File' > 'Shut Down' and re-open."
elif sudo systemctl is-active jupyter-server >/dev/null 2>&1; then
    sudo systemctl restart jupyter-server
else
    log_log "${QUIET}" "Jupyter server is not running; skipping restart."
fi
log_log "${QUIET}" "Jupyter registration complete."