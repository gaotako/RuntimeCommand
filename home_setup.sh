#!/bin/bash
# Set up persistent home directory overrides for Docker code-server.
#
# Symlinks `~/.ssh` and `~/.aws` from the container home to persistent storage
# directories, preserving any existing content. Clears `.profile` and `.bashrc`
# and symlinks `.bashrc` to persistent storage for shell customization.
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
# Notes
# -----
# This script operates on `DOCKER_HOME` (the persistent home directory for the
# Docker code-server container). Persistent storage directories are created
# under `PROJECT_ROOT` (the repo root) so they survive SageMaker restarts.
#
# Examples
# --------
# ```
# bash home_setup.sh
# bash home_setup.sh --log-depth 2
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source shared libraries and defaults.
source "${SCRIPT_DIR}/shutils/argparse.sh"
source "${SCRIPT_DIR}/shutils/log.sh"
source "${SCRIPT_DIR}/shutils/shell.sh"

# Parse arguments (may set LOG_DEPTH via --log-depth).
argparse::parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides DOCKER_HOME, PROJECT_ROOT via caller).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log::make_indent "${LOG_DEPTH}"

# Persistent storage root (sibling of src/RuntimeCommand in the repo tree).
PERSISTENT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SSH_HOME="${PERSISTENT_ROOT}/ssh"
AWS_HOME="${PERSISTENT_ROOT}/aws"
BASHRC_LINK="${PERSISTENT_ROOT}/bashrc.sh"

# Print header.
echo "${LOG_INDENT} Home Directory Setup"

# Symlink ~/.ssh to persistent storage, preserving existing content.
echo "${LOG_INDENT} [1/3] Setting up .ssh ..."
mkdir -p "${SSH_HOME}"
if [[ ! -L "${DOCKER_HOME}/.ssh" || "$(readlink -f "${DOCKER_HOME}/.ssh")" != "$(readlink -f "${SSH_HOME}")" ]]; then
    if [[ -n "$(ls "${DOCKER_HOME}/.ssh" 2>/dev/null)" ]]; then
        cp "${DOCKER_HOME}/.ssh/"* "${SSH_HOME}/"
    fi
    rm -rf "${DOCKER_HOME}/.ssh"
    ln -s "${SSH_HOME}" "${DOCKER_HOME}/.ssh"
fi

# Symlink ~/.aws to persistent storage, preserving existing content.
echo "${LOG_INDENT} [2/3] Setting up .aws ..."
mkdir -p "${AWS_HOME}"
if [[ ! -L "${DOCKER_HOME}/.aws" || "$(readlink -f "${DOCKER_HOME}/.aws")" != "$(readlink -f "${AWS_HOME}")" ]]; then
    if [[ -n "$(ls "${DOCKER_HOME}/.aws" 2>/dev/null)" ]]; then
        cp "${DOCKER_HOME}/.aws/"* "${AWS_HOME}/"
    fi
    rm -rf "${DOCKER_HOME}/.aws"
    ln -s "${AWS_HOME}" "${DOCKER_HOME}/.aws"
fi

# Set up .profile and .bashrc with persistent symlink.
# .bashrc sources docker/bashrc.sh (not copied, so path resolution works).
echo "${LOG_INDENT} [3/3] Setting up .profile and .bashrc ..."
[[ ! -f "${DOCKER_HOME}/.profile" ]] && touch "${DOCKER_HOME}/.profile"
[[ ! -f "${DOCKER_HOME}/.bashrc" ]] && touch "${DOCKER_HOME}/.bashrc"
: > "${DOCKER_HOME}/.profile"
echo "source ${DOCKER_HOME}/.bashrc" > "${DOCKER_HOME}/.profile"
echo "source ${SCRIPT_DIR}/bashrc.sh" > "${DOCKER_HOME}/.bashrc"
if [[ ! -L "${BASHRC_LINK}" || "$(readlink -f "${BASHRC_LINK}")" != "$(readlink -f "${DOCKER_HOME}/.bashrc")" ]]; then
    rm -rf "${BASHRC_LINK}"
    ln -s "${DOCKER_HOME}/.bashrc" "${BASHRC_LINK}"
fi
echo "${LOG_INDENT} Home directory setup complete."
