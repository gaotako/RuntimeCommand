#!/bin/bash
# Set up persistent home directory overrides for Docker code-server.
#
# Symlinks `~/.ssh` and `~/.aws` from the container home to persistent storage
# directories, preserving any existing content. Detects the current shell via
# `CISH` and sets up the appropriate rc files (`.bashrc`/`.profile` for
# bash/sh, `.zshrc`/`.zprofile` for zsh) so the interactive shell sources
# `rc.sh`.
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
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides DOCKER_HOME, PROJECT_ROOT via caller).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Persistent storage root (sibling of src/RuntimeCommand in the repo tree).
PERSISTENT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SSH_HOME="${PERSISTENT_ROOT}/ssh"
AWS_HOME="${PERSISTENT_ROOT}/aws"

# Ensure DOCKER_HOME exists (normally created by wrapper.sh at runtime).
mkdir -p "${DOCKER_HOME}"

# Print header.
echo "${LOG_INDENT} Home Directory Setup"

# Symlink ~/.ssh to persistent storage, preserving existing content.
# Generate an SSH identity (ecdsa, fallback to rsa) if none exists.
echo "${LOG_INDENT} [1/4] Setting up .ssh ..."
mkdir -p "${SSH_HOME}"
if [[ ! -L "${DOCKER_HOME}/.ssh" || "$(readlink -f "${DOCKER_HOME}/.ssh")" != "$(readlink -f "${SSH_HOME}")" ]]; then
    if [[ -n "$(ls "${DOCKER_HOME}/.ssh" 2>/dev/null)" ]]; then
        cp "${DOCKER_HOME}/.ssh/"* "${SSH_HOME}/"
    fi
    rm -rf "${DOCKER_HOME}/.ssh"
    ln -s "${SSH_HOME}" "${DOCKER_HOME}/.ssh"
fi
for encrypt in ecdsa rsa; do
    if [[ ! -f "${SSH_HOME}/id_${encrypt}" ]]; then
        if ssh-keygen -t "${encrypt}" -q -f "${SSH_HOME}/id_${encrypt}" -N ""; then
            break
        fi
    else
        break
    fi
done

# Symlink ~/.aws to persistent storage, preserving existing content.
echo "${LOG_INDENT} [2/4] Setting up .aws ..."
mkdir -p "${AWS_HOME}"
if [[ ! -L "${DOCKER_HOME}/.aws" || "$(readlink -f "${DOCKER_HOME}/.aws")" != "$(readlink -f "${AWS_HOME}")" ]]; then
    if [[ -n "$(ls "${DOCKER_HOME}/.aws" 2>/dev/null)" ]]; then
        cp "${DOCKER_HOME}/.aws/"* "${AWS_HOME}/"
    fi
    rm -rf "${DOCKER_HOME}/.aws"
    ln -s "${AWS_HOME}" "${DOCKER_HOME}/.aws"
fi

# Set up shell rc files for DOCKER_HOME and HOST HOME.
# DOCKER_HOME uses DOCKER_SHELL (from config.sh) to determine the rc file.
# HOST HOME uses CISH (from shell.sh) to detect the host's current shell.
# Both source rc.sh for environment setup.
echo "${LOG_INDENT} [3/4] Setting up shell rc files ..."
RC_MARKER_BEGIN="# >>> RuntimeCommand >>>"
RC_MARKER_END="# <<< RuntimeCommand <<<"
RC_SOURCE_LINE="source ${SCRIPT_DIR}/rc.sh"

# Derive rc file names from a shell path (/bin/zsh → .zshrc/.zprofile,
# /bin/bash or others → .bashrc/.profile).
_rc_files_for_shell() {
    case "${1}" in
    *zsh*)
        echo ".zshrc .zprofile"
        ;;
    *)
        echo ".bashrc .profile"
        ;;
    esac
}

# Set up DOCKER_HOME rc files (based on DOCKER_SHELL from config.sh).
read -r DOCKER_RC_FILE DOCKER_LOGIN_FILE <<< "$(_rc_files_for_shell "${DOCKER_SHELL}")"
echo "${RC_SOURCE_LINE}" > "${DOCKER_HOME}/${DOCKER_RC_FILE}"
echo "source ${DOCKER_HOME}/${DOCKER_RC_FILE}" > "${DOCKER_HOME}/${DOCKER_LOGIN_FILE}"

# Set up HOST HOME rc files (based on CISH from shell.sh).
read -r HOST_RC_FILE HOST_LOGIN_FILE <<< "$(_rc_files_for_shell "${CISH}")"
for target_home in "${HOME}"; do
    for rc_pair in "${HOST_RC_FILE}:${RC_SOURCE_LINE}" "${HOST_LOGIN_FILE}:source ${target_home}/${HOST_RC_FILE}"; do
        rc_file="${target_home}/${rc_pair%%:*}"
        rc_content="${rc_pair#*:}"
        [[ ! -f "${rc_file}" ]] && touch "${rc_file}"
        sed -i "/${RC_MARKER_BEGIN}/,/${RC_MARKER_END}/d" "${rc_file}"
        if [[ -s "${rc_file}" ]]; then
            echo "" >> "${rc_file}"
        fi
        echo "${RC_MARKER_BEGIN}" >> "${rc_file}"
        echo "${rc_content}" >> "${rc_file}"
        echo "${RC_MARKER_END}" >> "${rc_file}"
    done
done

# Symlink persistent rc file to HOST HOME's rc file.
RC_LINK="${PERSISTENT_ROOT}/${HOST_RC_FILE##.}.sh"
if [[ ! -L "${RC_LINK}" || "$(readlink -f "${RC_LINK}")" != "$(readlink -f "${HOME}/${HOST_RC_FILE}")" ]]; then
    rm -rf "${RC_LINK}"
    ln -s "${HOME}/${HOST_RC_FILE}" "${RC_LINK}"
fi

# Ensure XDG and application directories exist on the host.
echo "${LOG_INDENT} [4/4] Creating XDG and application directories ..."
mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}"
mkdir -p "${APP_ROOT}" "${APP_DATA_HOME}" "${APP_BIN_HOME}"
echo "${LOG_INDENT} Home directory setup complete."
