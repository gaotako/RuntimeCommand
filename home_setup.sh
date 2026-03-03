#!/bin/bash
# Set up persistent home directory overrides for Docker code-server.
#
# Symlinks `~/.ssh`, `~/.aws`, and `~/.midway` from both the container
# home and the host home to persistent storage directories, preserving
# existing content. Detects the user's login shell and sets up the
# appropriate rc files so the interactive shell sources `rc.sh`.
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
# under `PERSISTENT_ROOT` (the repo root) so they survive restarts.
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

# Merge and symlink a credential directory for both Docker and host.
#
# Copies content from Docker home and host home into the persistent
# target (host wins on conflicts), then replaces both with symlinks.
# Merge priority (high to low): host > Docker > persistent.
#
# Args
# ----
# - `dot_name`
#     The dotfile directory name (e.g., `.ssh`, `.aws`, `.midway`).
# - `persistent_dir`
#     Absolute path to the persistent storage directory.
#
# Returns
# -------
# (No-Returns)
_merge_and_symlink() {
    mkdir -p "${2}"

    if [[ ! -L "${DOCKER_HOME}/${1}" ]] && [[ -d "${DOCKER_HOME}/${1}" ]]; then
        cp -rn "${DOCKER_HOME}/${1}/"* "${2}/" 2>/dev/null || true
    fi

    if [[ "${HOME}" != "${DOCKER_HOME}" ]] && [[ ! -L "${HOME}/${1}" ]] && [[ -d "${HOME}/${1}" ]]; then
        cp -r "${HOME}/${1}/"* "${2}/" 2>/dev/null || true
    fi

    rm -rf "${DOCKER_HOME}/${1}"
    ln -s "${2}" "${DOCKER_HOME}/${1}" || echo "WARNING: Failed to symlink \`${DOCKER_HOME}/${1}\`." >&2

    if [[ "${HOME}" != "${DOCKER_HOME}" ]]; then
        rm -rf "${HOME}/${1}"
        ln -s "${2}" "${HOME}/${1}" || echo "WARNING: Failed to symlink \`${HOME}/${1}\`." >&2
    fi
}

# Set up .ssh (priority: host > Docker > persistent).
log_log "${QUIET}" "[2/6] Setting up .ssh ..."
_merge_and_symlink ".ssh" "${SSH_HOME}"

# Generate an SSH identity (ed25519 preferred, fallback to ecdsa, then rsa).
_ssh_ensure_key() {
    for KEY_TYPE in ed25519 ecdsa rsa; do
        if [[ -f "${SSH_HOME}/id_${KEY_TYPE}" ]]; then
            return 0
        fi
    done

    for KEY_TYPE in ed25519 ecdsa rsa; do
        if ssh-keygen -t "${KEY_TYPE}" -q -f "${SSH_HOME}/id_${KEY_TYPE}" -N ""; then
            return 0
        fi
    done

    echo "WARNING: Failed to generate SSH key (tried ed25519, ecdsa, rsa)." >&2
}
_ssh_ensure_key

# Set up .aws (priority: host > Docker > persistent).
log_log "${QUIET}" "[3/6] Setting up .aws ..."
_merge_and_symlink ".aws" "${AWS_HOME}"

# Set up .midway (priority: host > Docker > persistent).
log_log "${QUIET}" "[4/6] Setting up .midway ..."
_merge_and_symlink ".midway" "${MIDWAY_HOME}"

# Set up shell rc files for DOCKER_HOME and HOST HOME.
log_log "${QUIET}" "[5/6] Setting up shell rc files ..."
RC_MARKER_BEGIN="# >>> RuntimeCommand >>>"
RC_MARKER_END="# <<< RuntimeCommand <<<"
RC_SOURCE_LINE="source ${SCRIPT_DIR}/rc.sh"

# Derive rc file names from a shell path (/bin/zsh → .zshrc/.zprofile).
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

    RC_EXT_LINES=""
    if grep -qF "${RC_MARKER_BEGIN}" "${1}" 2>/dev/null; then
        RC_EXT_LINES="$(sed -n "/${RC_MARKER_BEGIN}/,/${RC_MARKER_END}/p" "${1}" | grep -v "${RC_MARKER_BEGIN}" | grep -v "${RC_MARKER_END}" | grep -vF "${2}" || true)"
    fi

    sed -i "/${RC_MARKER_BEGIN}/,/${RC_MARKER_END}/d" "${1}"
    sed -i '/^$/N;/^\n$/d' "${1}"
    if [[ -s "${1}" ]]; then
        echo "" >> "${1}"
    fi
    echo "${RC_MARKER_BEGIN}" >> "${1}"
    echo "${2}" >> "${1}"
    if [[ -n "${RC_EXT_LINES}" ]]; then
        echo "${RC_EXT_LINES}" >> "${1}"
    fi
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