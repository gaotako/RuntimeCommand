#!/bin/bash
# Remove the RuntimeCommand Docker container and optionally its data on macOS.
#
# Delegates to the shared removal logic in `remove_common.sh`.
#
# Args
# ----
# - `--purge`
#     Also remove the Docker home directory and all persisted data.
#     Without this flag, only the container is removed (data survives
#     for the next `wrapper.sh` cold-start).
# - `--yes`
#     Skip confirmation prompts.
#
# Returns
# -------
# (No-Returns)
#
# Examples
# --------
# ```
# bash remove.sh          # Remove container only (data preserved)
# bash remove.sh --purge  # Remove container + all Docker home data
# bash remove.sh --yes    # Skip confirmation
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load shared configuration (provides CONTAINER_RUNTIME, CONTAINER_NAME, etc.).
source "${PROJECT_ROOT}/config.sh"

# Source shared removal logic and run.
source "${PROJECT_ROOT}/remove_common.sh"
_remove_run "$@"
