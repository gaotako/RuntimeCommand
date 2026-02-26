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
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--quiet`
#     When set, suppresses step-by-step log output.
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
# bash home_setup.sh --quiet
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source shared libraries and defaults.
source "${SCRIPT_DIR}/shutils/argparse.sh"
source "${SCRIPT_DIR}/shutils/log.sh"
source "${SCRIPT_DIR}/shutils/shell.sh"

# Parse arguments (may set LOG_DEPTH, QUIET via --log-depth, --quiet).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides DOCKER_HOME, PROJECT_ROOT via caller).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve quiet flag from argparse (--quiet sets QUIET=1).
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# Persistent storage root (sibling of src/RuntimeCommand in the repo tree).
PERSISTENT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SSH_HOME="${PERSISTENT_ROOT}/ssh"
AWS_HOME="${PERSISTENT_ROOT}/aws"

# Ensure DOCKER_HOME and common subdirectories exist.
mkdir -p "${DOCKER_HOME}" "${DOCKER_HOME}/Workspace"

# Print header.
log_log "${QUIET}" "Home Directory Setup"

# Write DOCKER_HOME .vimrc that sources the project vimrc.
log_log "${QUIET}" "[1/5] Setting up .vimrc ..."
VIMRC_SOURCE="${SCRIPT_DIR}/vimrc"
VIMRC_TARGET="${DOCKER_HOME}/.vimrc"
if [[ -f "${VIMRC_SOURCE}" ]]; then
    echo "source ${VIMRC_SOURCE}" > "${VIMRC_TARGET}"
fi

# Symlink ~/.ssh to persistent storage, preserving existing content.
# Generate an SSH identity (ed25519, fallback to ecdsa, then rsa) if none exists.
log_log "${QUIET}" "[2/5] Setting up .ssh ..."
mkdir -p "${SSH_HOME}"
if [[ ! -L "${DOCKER_HOME}/.ssh" || "$(readlink -f "${DOCKER_HOME}/.ssh")" != "$(readlink -f "${SSH_HOME}")" ]]; then
    if [[ -n "$(ls "${DOCKER_HOME}/.ssh" 2>/dev/null)" ]]; then
        cp -r "${DOCKER_HOME}/.ssh/"* "${SSH_HOME}/"
    fi
    rm -rf "${DOCKER_HOME}/.ssh"
    ln -s "${SSH_HOME}" "${DOCKER_HOME}/.ssh"
fi
for KEY_TYPE in ed25519 ecdsa rsa; do
    if [[ ! -f "${SSH_HOME}/id_${KEY_TYPE}" ]]; then
        if ssh-keygen -t "${KEY_TYPE}" -q -f "${SSH_HOME}/id_${KEY_TYPE}" -N ""; then
            break
        fi
    else
        break
    fi
done

# Add persistent SSH key as an additional identity on the host.
# This allows git operations on the SageMaker host (outside Docker) to use
# the same key as inside Docker, without modifying the host's existing keys.
HOST_SSH_DIR="${HOME}/.ssh"
HOST_SSH_CONFIG="${HOST_SSH_DIR}/config"
if [[ -d "${SSH_HOME}" && "${HOME}" != "${DOCKER_HOME}" ]]; then
    mkdir -p "${HOST_SSH_DIR}"
    SSH_IDENTITY_LINE="IdentityFile ${SSH_HOME}/id_ed25519"
    if ! grep -qF "${SSH_IDENTITY_LINE}" "${HOST_SSH_CONFIG}" 2>/dev/null; then
        echo "" >> "${HOST_SSH_CONFIG}"
        echo "# RuntimeCommand persistent SSH key." >> "${HOST_SSH_CONFIG}"
        echo "Host *" >> "${HOST_SSH_CONFIG}"
        echo "    ${SSH_IDENTITY_LINE}" >> "${HOST_SSH_CONFIG}"
    fi
fi

# Symlink ~/.aws to persistent storage, preserving existing content.
log_log "${QUIET}" "[3/5] Setting up .aws ..."
mkdir -p "${AWS_HOME}"
if [[ ! -L "${DOCKER_HOME}/.aws" || "$(readlink -f "${DOCKER_HOME}/.aws")" != "$(readlink -f "${AWS_HOME}")" ]]; then
    if [[ -n "$(ls "${DOCKER_HOME}/.aws" 2>/dev/null)" ]]; then
        cp -r "${DOCKER_HOME}/.aws/"* "${AWS_HOME}/"
    fi
    rm -rf "${DOCKER_HOME}/.aws"
    ln -s "${AWS_HOME}" "${DOCKER_HOME}/.aws"
fi

# Set up shell rc files for DOCKER_HOME and HOST HOME.
# DOCKER_HOME uses DOCKER_SHELL (from config.sh) to determine the rc file.
# HOST HOME uses CISH (from shell.sh) to detect the host's current shell.
# Both source rc.sh for environment setup.
log_log "${QUIET}" "[4/5] Setting up shell rc files ..."
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
# Writes RC_DIR directly before sourcing rc.sh so it doesn't need to
# auto-detect its own location (zsh source path detection is unreliable).
read -r DOCKER_RC_FILE DOCKER_LOGIN_FILE <<< "$(_rc_files_for_shell "${DOCKER_SHELL}")"
{
    echo "export RC_DIR=\"${SCRIPT_DIR}\""
    echo "${RC_SOURCE_LINE}"
} > "${DOCKER_HOME}/${DOCKER_RC_FILE}"
echo "source ${DOCKER_HOME}/${DOCKER_RC_FILE}" > "${DOCKER_HOME}/${DOCKER_LOGIN_FILE}"

# Set up HOST HOME rc files (based on CISH from shell.sh).
RC_BLOCK="export RC_DIR=\"${SCRIPT_DIR}\"
${RC_SOURCE_LINE}"
read -r HOST_RC_FILE HOST_LOGIN_FILE <<< "$(_rc_files_for_shell "${CISH}")"
TARGET_HOME="${HOME}"
for RC_PAIR in "${HOST_RC_FILE}:${RC_BLOCK}" "${HOST_LOGIN_FILE}:source ${TARGET_HOME}/${HOST_RC_FILE}"; do
    RC_FILE_TARGET="${TARGET_HOME}/${RC_PAIR%%:*}"
    RC_CONTENT="${RC_PAIR#*:}"
    [[ ! -f "${RC_FILE_TARGET}" ]] && touch "${RC_FILE_TARGET}"
    sed -i "/${RC_MARKER_BEGIN}/,/${RC_MARKER_END}/d" "${RC_FILE_TARGET}"
    if [[ -s "${RC_FILE_TARGET}" ]]; then
        echo "" >> "${RC_FILE_TARGET}"
    fi
    echo "${RC_MARKER_BEGIN}" >> "${RC_FILE_TARGET}"
    echo "${RC_CONTENT}" >> "${RC_FILE_TARGET}"
    echo "${RC_MARKER_END}" >> "${RC_FILE_TARGET}"
done

# Symlink persistent rc file to HOST HOME's rc file.
RC_LINK="${PERSISTENT_ROOT}/${HOST_RC_FILE##.}.sh"
if [[ ! -L "${RC_LINK}" || "$(readlink -f "${RC_LINK}")" != "$(readlink -f "${HOME}/${HOST_RC_FILE}")" ]]; then
    rm -rf "${RC_LINK}"
    ln -s "${HOME}/${HOST_RC_FILE}" "${RC_LINK}"
fi

# Ensure XDG and application directories exist on the host.
log_log "${QUIET}" "[5/5] Creating XDG and application directories ..."
mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}"
mkdir -p "${APP_ROOT}" "${APP_DATA_HOME}" "${APP_BIN_HOME}"
log_log "${QUIET}" "Home directory setup complete."