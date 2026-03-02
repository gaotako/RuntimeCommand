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
MIDWAY_HOME="${PERSISTENT_ROOT}/midway"

# Ensure DOCKER_HOME and common subdirectories exist.
mkdir -p "${DOCKER_HOME}" "${DOCKER_HOME}/Workspace"
ln -sfn "${DOCKER_HOME}/Workspace" "${DOCKER_HOME}/Desktop"

# Print header.
log_log "${QUIET}" "Home Directory Setup"

# Write DOCKER_HOME .vimrc that sources the project vimrc.
log_log "${QUIET}" "[1/6] Setting up .vimrc ..."
VIMRC_SOURCE="${SCRIPT_DIR}/vimrc"
VIMRC_TARGET="${DOCKER_HOME}/.vimrc"
if [[ -f "${VIMRC_SOURCE}" ]]; then
    echo "source ${VIMRC_SOURCE}" > "${VIMRC_TARGET}"
fi

# Merge and symlink .ssh for Docker and host to persistent storage.
#
# Merge priority (high to low): system (host) > Docker > persistent.
# Docker content is copied first (fills gaps), then host content
# overwrites (highest priority). Both dirs are then symlinked.
# Generates an SSH identity if none exists after merging.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)
_setup_ssh() {
    mkdir -p "${SSH_HOME}"

    if [[ ! -L "${DOCKER_HOME}/.ssh" ]] && [[ -d "${DOCKER_HOME}/.ssh" ]]; then
        cp -rn "${DOCKER_HOME}/.ssh/"* "${SSH_HOME}/" 2>/dev/null || true
    fi

    if [[ "${HOME}" != "${DOCKER_HOME}" ]] && [[ ! -L "${HOME}/.ssh" ]] && [[ -d "${HOME}/.ssh" ]]; then
        cp -r "${HOME}/.ssh/"* "${SSH_HOME}/" 2>/dev/null || true
    fi

    rm -rf "${DOCKER_HOME}/.ssh"
    ln -s "${SSH_HOME}" "${DOCKER_HOME}/.ssh"

    if [[ "${HOME}" != "${DOCKER_HOME}" ]]; then
        rm -rf "${HOME}/.ssh"
        ln -s "${SSH_HOME}" "${HOME}/.ssh"
    fi

    GENERATED_KEY_TYPE=""
    for KEY_TYPE in ed25519 ecdsa rsa; do
        if [[ ! -f "${SSH_HOME}/id_${KEY_TYPE}" ]]; then
            if ssh-keygen -t "${KEY_TYPE}" -q -f "${SSH_HOME}/id_${KEY_TYPE}" -N ""; then
                GENERATED_KEY_TYPE="${KEY_TYPE}"
                break
            fi
        else
            GENERATED_KEY_TYPE="${KEY_TYPE}"
            break
        fi
    done
}

# Merge and symlink .aws for Docker and host to persistent storage.
#
# Same merge priority as SSH: system (host) > Docker > persistent.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)
_setup_aws() {
    mkdir -p "${AWS_HOME}"

    if [[ ! -L "${DOCKER_HOME}/.aws" ]] && [[ -d "${DOCKER_HOME}/.aws" ]]; then
        cp -rn "${DOCKER_HOME}/.aws/"* "${AWS_HOME}/" 2>/dev/null || true
    fi

    if [[ "${HOME}" != "${DOCKER_HOME}" ]] && [[ ! -L "${HOME}/.aws" ]] && [[ -d "${HOME}/.aws" ]]; then
        cp -r "${HOME}/.aws/"* "${AWS_HOME}/" 2>/dev/null || true
    fi

    rm -rf "${DOCKER_HOME}/.aws"
    ln -s "${AWS_HOME}" "${DOCKER_HOME}/.aws"

    if [[ "${HOME}" != "${DOCKER_HOME}" ]]; then
        rm -rf "${HOME}/.aws"
        ln -s "${AWS_HOME}" "${HOME}/.aws"
    fi
}

# Set up .ssh (priority: host > Docker > persistent).
log_log "${QUIET}" "[2/6] Setting up .ssh ..."
_setup_ssh

# Set up .aws (priority: host > Docker > persistent).
log_log "${QUIET}" "[3/6] Setting up .aws ..."
_setup_aws

# Merge and symlink .midway for Docker and host to persistent storage.
#
# Same merge priority as SSH and AWS: system (host) > Docker > persistent.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)
_setup_midway() {
    mkdir -p "${MIDWAY_HOME}"

    if [[ ! -L "${DOCKER_HOME}/.midway" ]] && [[ -d "${DOCKER_HOME}/.midway" ]]; then
        cp -rn "${DOCKER_HOME}/.midway/"* "${MIDWAY_HOME}/" 2>/dev/null || true
    fi

    if [[ "${HOME}" != "${DOCKER_HOME}" ]] && [[ ! -L "${HOME}/.midway" ]] && [[ -d "${HOME}/.midway" ]]; then
        cp -r "${HOME}/.midway/"* "${MIDWAY_HOME}/" 2>/dev/null || true
    fi

    rm -rf "${DOCKER_HOME}/.midway"
    ln -s "${MIDWAY_HOME}" "${DOCKER_HOME}/.midway"

    if [[ "${HOME}" != "${DOCKER_HOME}" ]]; then
        rm -rf "${HOME}/.midway"
        ln -s "${MIDWAY_HOME}" "${HOME}/.midway"
    fi
}

# Set up .midway (priority: host > Docker > persistent).
log_log "${QUIET}" "[4/6] Setting up .midway ..."
_setup_midway

# Set up shell rc files for DOCKER_HOME and HOST HOME.
# DOCKER_HOME uses DOCKER_SHELL (from config.sh) to determine the rc file.
# HOST HOME uses CISH (from shell.sh) to detect the host's current shell.
# Both source rc.sh for environment setup.
log_log "${QUIET}" "[5/6] Setting up shell rc files ..."
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

# Append a marker-fenced block to a file, replacing any existing block.
#
# Removes any existing RuntimeCommand block, collapses consecutive blank
# lines left behind, then appends the new block at the end preceded by
# exactly one blank line separator.
#
# Args
# ----
# - `target_file`
#     Path to the rc file to modify.
# - `content`
#     Content to place between the marker fences.
#
# Returns
# -------
# (No-Returns)
_rc_register_block() {
    [[ ! -f "${1}" ]] && touch "${1}"
    sed -i "/${RC_MARKER_BEGIN}/,/${RC_MARKER_END}/d" "${1}"
    sed -i '/^$/N;/^\n$/d' "${1}"
    if [[ -s "${1}" ]]; then
        echo "" >> "${1}"
    fi
    echo "${RC_MARKER_BEGIN}" >> "${1}"
    echo "${2}" >> "${1}"
    echo "${RC_MARKER_END}" >> "${1}"
}

# Set up HOST HOME rc files (based on SHELL env var, the user's login shell).
RC_BLOCK="export RC_DIR=\"${SCRIPT_DIR}\"
${RC_SOURCE_LINE}"
read -r HOST_RC_FILE HOST_LOGIN_FILE <<< "$(_rc_files_for_shell "${SHELL}")"
TARGET_HOME="${HOME}"
_rc_register_block "${TARGET_HOME}/${HOST_RC_FILE}" "${RC_BLOCK}"
_rc_register_block "${TARGET_HOME}/${HOST_LOGIN_FILE}" "source ${TARGET_HOME}/${HOST_RC_FILE}"

# Symlink persistent rc files and cishrc.sh to HOST HOME's rc file.
RC_LINK="${PERSISTENT_ROOT}/${HOST_RC_FILE##.}.sh"
if [[ ! -L "${RC_LINK}" || "$(readlink -f "${RC_LINK}")" != "$(readlink -f "${HOME}/${HOST_RC_FILE}")" ]]; then
    rm -rf "${RC_LINK}"
    ln -s "${HOME}/${HOST_RC_FILE}" "${RC_LINK}"
fi
CISHRC_LINK="${PERSISTENT_ROOT}/cishrc.sh"
if [[ ! -L "${CISHRC_LINK}" || "$(readlink -f "${CISHRC_LINK}")" != "$(readlink -f "${HOME}/${HOST_RC_FILE}")" ]]; then
    rm -rf "${CISHRC_LINK}"
    ln -s "${HOME}/${HOST_RC_FILE}" "${CISHRC_LINK}"
fi

# Ensure XDG and application directories exist on the host.
log_log "${QUIET}" "[6/6] Creating XDG and application directories ..."
mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}"
mkdir -p "${APP_ROOT}" "${APP_DATA_HOME}" "${APP_BIN_HOME}"
log_log "${QUIET}" "Home directory setup complete."