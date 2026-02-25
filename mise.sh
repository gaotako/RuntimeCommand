#!/bin/bash
# Install and configure mise (polyglot runtime manager).
#
# Downloads the mise binary to `MISE_INSTALL_PATH` if not already present, sets
# up XDG-based directories for mise, migrates any existing mise installs
# from default locations, enables experimental features, and checks or
# installs the configured runtimes (Node, Python).
#
# Shell-aware activation supports bash/sh and zsh via the `CISH` variable
# from `shell.sh`.
#
# Args
# ----
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--coldstart`
#     When set, installs mise binary and runtimes from scratch. Without
#     this flag the script checks for missing runtimes and prints install
#     instructions.
# - `--quiet`
#     When set, suppresses step-by-step log output. Only "Missing ..."
#     messages are printed.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# The following environment variables can override default paths:
# - `MISE_INSTALL_PATH`
#     Path to the mise binary (default: `/usr/local/bin/mise`).
# - `MISE_NODE_VERSION`
#     Node.js version to install (default: `22`).
# - `MISE_PYTHON_VERSIONS`
#     Space-separated Python versions to install via `mise use -g`
#     (default: `"python@3.13 python@3.12 python@3.11 python@3.10"`).
#
# Mise stores its data, config, and cache under the XDG base directories
# (`XDG_DATA_HOME/mise`, `XDG_CONFIG_HOME/mise`, `XDG_CACHE_HOME/mise`)
# which are defined in `config.sh`.
#
# Examples
# --------
# ```
# bash mise.sh --coldstart
# bash mise.sh --coldstart --log-depth 2
# bash mise.sh --quiet
# bash mise.sh
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source shared libraries and defaults.
source "${SCRIPT_DIR}/shutils/argparse.sh"
source "${SCRIPT_DIR}/shutils/log.sh"
source "${SCRIPT_DIR}/shutils/shell.sh"

# Parse arguments (may set LOG_DEPTH, COLDSTART, QUIET via argparse).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides APP_BIN_HOME, XDG paths, MISE_* vars).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve flags from argparse (--coldstart sets COLDSTART=1, --quiet sets QUIET=1).
COLDSTART_DEFAULT=0
COLDSTART="${COLDSTART:-${COLDSTART_DEFAULT}}"
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# If mise is not installed and not in coldstart mode, print instructions
# and skip all mise operations to avoid startup delays.
if [[ ! -f "${MISE_INSTALL_PATH}" && "${COLDSTART}" -eq 0 ]]; then
    echo "Missing \`mise\`. Run \`bash ${SCRIPT_DIR}/mise.sh --coldstart\` to install."
    exit 0
fi

# Print header.
log_log "${QUIET}" "Mise Runtime Manager Setup"
log_log "${QUIET}" "Binary: ${MISE_INSTALL_PATH}"

# Install the mise binary if not already present (coldstart mode only).
log_log "${QUIET}" "[1/5] Checking mise binary ..."
if [[ ! -f "${MISE_INSTALL_PATH}" ]]; then
    log_log "${QUIET}" "Downloading mise ..."
    curl -fsSL https://mise.run | MISE_INSTALL_PATH="${MISE_INSTALL_PATH}" sh
else
    log_log "${QUIET}" "mise binary already present."
fi

# Ensure mise XDG directories exist.
log_log "${QUIET}" "[2/5] Creating mise directories ..."
mkdir -p "${XDG_DATA_HOME}/mise" "${XDG_CONFIG_HOME}/mise" "${XDG_CACHE_HOME}/mise"

# Migrate existing mise installs from default locations to XDG paths.
# Must happen BEFORE activation to avoid "untrusted config" errors from
# stale config files in ~/.config/mise/.
log_log "${QUIET}" "[3/5] Migrating existing mise data ..."
if [[ -f "${HOME}/.config/mise/config.toml" ]]; then
    log_log "${QUIET}" "Migrating config from ~/.config/mise/ ..."
    mv "${HOME}/.config/mise/config.toml" "${XDG_CONFIG_HOME}/mise/config.toml"
fi
for RUNTIME in node python; do
    DEFAULT_MISE_INSTALLS="${HOME}/.local/share/mise/installs/${RUNTIME}"
    if [[ -d "${DEFAULT_MISE_INSTALLS}" ]]; then
        log_log "${QUIET}" "Adopting existing ${RUNTIME} installs ..."
        rm -rf "${XDG_DATA_HOME}/mise/installs/${RUNTIME}"
        mkdir -p "${XDG_DATA_HOME}/mise/installs/${RUNTIME}"
        for VERSION_DIR in "${DEFAULT_MISE_INSTALLS}"/*/; do
            VERSION="$(basename "${VERSION_DIR}")"
            ln -s "${DEFAULT_MISE_INSTALLS}/${VERSION}" \
                "${XDG_DATA_HOME}/mise/installs/${RUNTIME}/${VERSION}"
        done
    fi
done

# Activate mise for the current session using the detected shell handler.
# CISH is set by shell.sh and indicates the current interactive shell.
log_log "${QUIET}" "[4/5] Activating mise (${CISH}) ..."
case "${CISH}" in
*zsh*)
    eval "$("${MISE_INSTALL_PATH}" activate zsh)"
    ;;
*bash*|*sh*)
    eval "$("${MISE_INSTALL_PATH}" activate bash)"
    ;;
*)
    echo "WARNING: Unknown shell \`${CISH}\`. \`mise\` is not activated." >&2
    ;;
esac

# Enable experimental features and configure mise settings.
# Disable Node GPG signature verification because SageMaker AL2 ships with
# outdated GPG keys that cannot validate Node.js release signatures. Mise
# still verifies downloads via SHA256 checksums.
log_log "${QUIET}" "[5/5] Checking runtimes ..."
"${MISE_INSTALL_PATH}" settings experimental=true 2>/dev/null
"${MISE_INSTALL_PATH}" settings node.gpg_verify=false 2>/dev/null

# Check or install runtimes based on coldstart flag.
# In coldstart mode, install all runtimes. Otherwise, check each runtime
# and print install instructions for any that are missing.
if [[ "${COLDSTART}" -eq 1 ]]; then
    # shellcheck disable=SC2086
    "${MISE_INSTALL_PATH}" use -g "node@${MISE_NODE_VERSION}" ${MISE_PYTHON_VERSIONS}
else
    "${MISE_INSTALL_PATH}" settings set not_found_auto_install 0 2>/dev/null
    if ! "${MISE_INSTALL_PATH}" which node &>/dev/null; then
        echo "Missing \`node\`. Run \`${MISE_INSTALL_PATH} use -g node@${MISE_NODE_VERSION}\` to install."
    fi
    if ! "${MISE_INSTALL_PATH}" which python3 &>/dev/null; then
        echo "Missing \`python\`. Run \`${MISE_INSTALL_PATH} use -g ${MISE_PYTHON_VERSIONS}\` to install."
    fi
fi
log_log "${QUIET}" "Mise setup complete."