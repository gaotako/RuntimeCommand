#!/bin/bash
# Default bashrc for Docker code-server.
#
# Sourced on every interactive shell session inside the container.
# Checks shell compatibility and warns if the handler is not bash.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)

# Resolve the project root from this file's persistent symlink target.
BASHRC_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_ROOT="$(cd "${BASHRC_DIR}" && pwd)"

# Source shell handler detection and warn if not bash-compatible.
source "${PROJECT_ROOT}/shutils/shell.sh"
shell::check_bash_compat