#!/bin/bash
# Install and configure mise (polyglot runtime manager).
#
# Downloads the mise binary to `APP_BIN_HOME` if not already present, sets
# up XDG-based directories for mise, migrates any existing mise installs
# from default locations, enables experimental features, and installs the
# configured runtimes (Node, Python).
#
# Shell-aware activation supports bash/sh and zsh via the `CISH` variable
# from `shell.sh`.
#
# Args
# ----
# - --log-depth LOG_DEPTH
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - --coldstart
#     When set, installs mise binary and runtimes from scratch. Without
#     this flag the script only verifies the installation is intact.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# The following environment variables can override default paths:
# - `MISE_INSTALL_PATH`
#     Path to the mise binary (default: `APP_BIN_HOME/mise`).
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
# bash mise.sh
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source shared libraries and defaults.
source "${SCRIPT_DIR}/shutils/argparse.sh"
source "${SCRIPT_DIR}/shutils/log.sh"
source "${SCRIPT_DIR}/shutils/shell.sh"

# Parse arguments (may set LOG_DEPTH, COLDSTART via argparse).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides APP_BIN_HOME, XDG paths, MISE_* vars).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve coldstart flag from argparse (--coldstart sets COLDSTART=1).
COLDSTART_DEFAULT=0
COLDSTART="${COLDSTART:-${COLDSTART_DEFAULT}}"

# Print header.
echo "${LOG_INDENT} Mise Runtime Manager Setup"
echo "${LOG_INDENT} Binary: ${MISE_INSTALL_PATH}"

# Install the mise binary if not already present.
echo "${LOG_INDENT} [1/5] Checking mise binary ..."
if [[ ! -f "${MISE_INSTALL_PATH}" ]]; then
    if [[ "${COLDSTART}" -eq 0 ]]; then
        echo "${LOG_INDENT} ERROR: mise is not installed at ${MISE_INSTALL_PATH}."
        exit 1
    fi
    echo "${LOG_INDENT} Downloading mise ..."
    curl -fsSL https://mise.run | MISE_INSTALL_PATH="${MISE_INSTALL_PATH}" sh
else
    echo "${LOG_INDENT} mise binary already present."
fi

# Ensure mise XDG directories exist.
echo "${LOG_INDENT} [2/5] Creating mise directories ..."
mkdir -p "${XDG_DATA_HOME}/mise" "${XDG_CONFIG_HOME}/mise" "${XDG_CACHE_HOME}/mise"

# Activate mise for the current session using the detected shell handler.
# CISH is set by shell.sh and indicates the current interactive shell.
echo "${LOG_INDENT} [3/5] Activating mise (${CISH}) ..."
case "${CISH}" in
*bash*|*sh*)
    eval "$("${MISE_INSTALL_PATH}" activate bash)"
    ;;
*zsh*)
    eval "$("${MISE_INSTALL_PATH}" activate zsh)"
    ;;
*)
    echo "${LOG_INDENT} WARNING: Unknown shell '${CISH}', mise is not activated." >&2
    ;;
esac

# Migrate existing mise installs from default locations to XDG paths.
# If previous installs exist under ~/.config/mise or ~/.local/share/mise,
# move or symlink them into the XDG-based directories so mise picks them up.
echo "${LOG_INDENT} [4/5] Migrating existing mise data ..."
if [[ -f "${HOME}/.config/mise/config.toml" ]]; then
    echo "${LOG_INDENT} Migrating config from ~/.config/mise/ ..."
    mv "${HOME}/.config/mise/config.toml" "${XDG_CONFIG_HOME}/mise/config.toml"
fi
for module_alt in node python; do
    DEFAULT_MISE_INSTALLS="${HOME}/.local/share/mise/installs/${module_alt}"
    if [[ -d "${DEFAULT_MISE_INSTALLS}" ]]; then
        echo "${LOG_INDENT} Adopting existing ${module_alt} installs ..."
        rm -rf "${XDG_DATA_HOME}/mise/installs/${module_alt}"
        mkdir -p "${XDG_DATA_HOME}/mise/installs/${module_alt}"
        for version in $(ls "${DEFAULT_MISE_INSTALLS}"); do
            ln -s "${DEFAULT_MISE_INSTALLS}/${version}" \
                "${XDG_DATA_HOME}/mise/installs/${module_alt}/${version}"
        done
    fi
done

# Enable experimental features and configure mise settings.
# Disable Node GPG signature verification because SageMaker AL2 ships with
# outdated GPG keys that cannot validate Node.js release signatures. Mise
# still verifies downloads via SHA256 checksums.
echo "${LOG_INDENT} [5/5] Installing runtimes ..."
"${MISE_INSTALL_PATH}" settings experimental=true
"${MISE_INSTALL_PATH}" settings node.gpg_verify=false
if [[ "${COLDSTART}" -eq 0 ]]; then
    "${MISE_INSTALL_PATH}" settings set not_found_auto_install 0
fi

# Install the configured runtimes globally.
# shellcheck disable=SC2086
"${MISE_INSTALL_PATH}" use -g "node@${MISE_NODE_VERSION}" ${MISE_PYTHON_VERSIONS}
echo "${LOG_INDENT} Mise setup complete."