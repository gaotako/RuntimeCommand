#!/bin/bash
# SageMaker Notebook Instance lifecycle configuration: start hook.
#
# Runs every time the notebook instance starts (including after restart).
# Loads the Docker image from persistent storage (saved during create) and
# re-registers code-server with Jupyter since the root volume is ephemeral.
#
# Args
# ----
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--quiet`
#     When set, suppresses step-by-step log output. Inherited by all
#     sub-scripts.
#
# Returns
# -------
# (No-Returns)
#
# Examples
# --------
# In SageMaker lifecycle configuration console:
# ```
# #!/bin/bash
# set -euo pipefail
# RC_ROOT=/home/ec2-user/SageMaker/RuntimeCommandDev/src/RuntimeCommand
# bash "${RC_ROOT}/sagemaker/lifecycle/notebook_instance/start.sh"
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
SAGEMAKER_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$(cd "${SAGEMAKER_ROOT}/.." && pwd)"

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

# Build quiet flag for sub-scripts.
QUIET_FLAG=""
[[ "${QUIET}" -eq 1 ]] && QUIET_FLAG="--quiet"

# Remove readiness flag so rc.sh shows "not ready" during setup.
RC_READY_FLAG="${APP_DATA_HOME}/.rc_ready"
rm -f "${RC_READY_FLAG}"

# Skip if `create.sh` is already running (first boot runs both hooks).
if pgrep -f "lifecycle/notebook_instance/create.sh" &>/dev/null; then
    log_log "${QUIET}" "Create lifecycle is already running. Skipping start to avoid conflicts."
    exit 0
fi

# Wait for Docker daemon to be fully ready.
log_log "${QUIET}" "Waiting for \`docker\` daemon to stabilize ..."
DOCKER_WAIT=0
while ! docker info &>/dev/null; do
    sleep 2
    DOCKER_WAIT=$((DOCKER_WAIT + 2))
    if [[ "${DOCKER_WAIT}" -ge 120 ]]; then
        echo "ERROR: \`docker\` daemon did not become ready within 120 seconds." >&2
        exit 1
    fi
done

# Extra wait for daemon to finish any post-restart initialization.
sleep 5
log_log "${QUIET}" "\`docker\` daemon is ready (waited ${DOCKER_WAIT}s)."

# Print lifecycle header.
log_log "${QUIET}" "Code-Server Docker Lifecycle (start)"

# Set up persistent home directory overrides (.ssh, .aws, .bashrc).
bash "${PROJECT_ROOT}/home_setup.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}

# Install code-server (loads cached Docker image + places wrapper).
bash "${SAGEMAKER_ROOT}/install.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}

# Register code-server with JupyterLab and print completion footer.
bash "${SAGEMAKER_ROOT}/setup_jupyter.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}

# Mark setup as complete so rc.sh stops showing the "not ready" hint.
mkdir -p "$(dirname "${RC_READY_FLAG}")"
touch "${RC_READY_FLAG}"

log_log "${QUIET}" "Code-Server Docker Lifecycle (start) complete."
