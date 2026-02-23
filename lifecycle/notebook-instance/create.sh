#!/bin/bash
# SageMaker Notebook Instance lifecycle configuration: create hook.
#
# Runs once when the notebook instance is first created. Builds the Docker
# image, installs the wrapper script, and registers code-server with Jupyter.
#
# Args
# ----
# - --log-depth LOG_DEPTH
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
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
# RC_ROOT=/home/ec2-user/SageMaker/RuntimeCommandReadOnly/src/RuntimeCommand
# mkdir -p "${RC_ROOT}"
# git clone https://github.com/gaotako/RuntimeCommand "${RC_ROOT}"
# bash "${RC_ROOT}/lifecycle/notebook-instance/create.sh"
# ```
set -euo pipefail

# Resolve the project root directory (two levels up from this script).
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH via --log-depth).
argparse::parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (respects values already set by argparse).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log::make_indent "${LOG_DEPTH}"

# Print lifecycle header.
echo "${LOG_INDENT} Code-Server Docker Lifecycle (create)"

# Install code-server (build Docker image + place wrapper).
bash "${PROJECT_ROOT}/install.sh" --log-depth $((LOG_DEPTH + 1))

# Register code-server with JupyterLab and print completion footer.
bash "${PROJECT_ROOT}/setup_jupyter.sh" --log-depth $((LOG_DEPTH + 1))
echo "${LOG_INDENT} Code-Server Docker Lifecycle (create) complete."
