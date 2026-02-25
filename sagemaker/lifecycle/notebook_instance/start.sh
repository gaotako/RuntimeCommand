#!/bin/bash
# SageMaker Notebook Instance lifecycle configuration: start hook.
#
# Runs every time the notebook instance starts (including after restart).
# Loads the Docker image from persistent storage (saved during create) and
# re-registers code-server with Jupyter since the root volume is ephemeral.
#
# Args
# ----
# - --log-depth LOG_DEPTH
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - --quiet
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

# Print lifecycle header.
log_log "${QUIET}" "Code-Server Docker Lifecycle (start)"

# Set up persistent home directory overrides (.ssh, .aws, .bashrc).
bash "${PROJECT_ROOT}/home_setup.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}

# Install code-server (loads cached Docker image + places wrapper).
bash "${SAGEMAKER_ROOT}/install.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}

# Register code-server with JupyterLab and print completion footer.
bash "${SAGEMAKER_ROOT}/setup_jupyter.sh" --log-depth $((LOG_DEPTH + 1)) ${QUIET_FLAG}
log_log "${QUIET}" "Code-Server Docker Lifecycle (start) complete."