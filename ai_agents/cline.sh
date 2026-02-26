#!/bin/bash
# Install and configure the Cline CLI and code-server extension.
#
# Installs the Cline CLI via npm (requires Node.js from mise) and copies
# the Cline global state (Bedrock API configuration) to the Docker home
# directory.
#
# Args
# ----
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--coldstart`
#     When set, installs Cline CLI from scratch. Without this flag the
#     script checks for missing dependencies and prints install
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
# - Cline CLI is installed globally via `npm install -g cline`.
# - Node.js must be available (installed by mise) before running this script
#   in `--coldstart` mode.
# - Only `globalState.json` is maintained — workspace states are ephemeral.
# - The global state file is copied from `cline/globalState.json` in the
#   project directory to `DOCKER_HOME/.cline/data/globalState.json`.
# - The file is only copied if it does not already exist, to avoid
#   overwriting user-modified settings.
#
# Examples
# --------
# ```
# bash cline.sh --coldstart
# bash cline.sh --coldstart --log-depth 2
# bash cline.sh --quiet
# bash cline.sh
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH, COLDSTART, QUIET via argparse).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides DOCKER_HOME, MISE_INSTALL_PATH, etc.).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve flags from argparse (--coldstart sets COLDSTART=1, --quiet sets QUIET=1).
COLDSTART_DEFAULT=0
COLDSTART="${COLDSTART:-${COLDSTART_DEFAULT}}"
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# Cline CLI install location.
# Installed via npm into mise's active node bin directory.
CLINE_BIN=""
MISE_NODE_DIR="$("${MISE_INSTALL_PATH}" where node 2>/dev/null)" || true
if [[ -n "${MISE_NODE_DIR}" && -f "${MISE_NODE_DIR}/bin/cline" ]]; then
    CLINE_BIN="${MISE_NODE_DIR}/bin/cline"
fi

# Print header.
log_log "${QUIET}" "Cline CLI Setup"

# Step 1: Install or check Cline CLI.
log_log "${QUIET}" "[1/2] Checking Cline CLI ..."
if [[ "${COLDSTART}" -eq 1 ]]; then
    if [[ -n "${CLINE_BIN}" ]] || command -v cline &>/dev/null; then
        log_log "${QUIET}" "Cline CLI already installed."
    elif command -v npm &>/dev/null; then
        log_log "${QUIET}" "Installing Cline CLI via npm ..."
        npm install -g cline
    else
        echo "WARNING: \`npm\` is not available. Install Node.js first (via \`mise\`), then re-run." >&2
    fi
else
    # Check mise's active node bin path and command PATH.
    if [[ -z "${CLINE_BIN}" ]] && ! command -v cline &>/dev/null; then
        echo "Missing \`cline\`. Run \`bash ${SCRIPT_DIR}/cline.sh --coldstart\` to install."
    else
        log_log "${QUIET}" "Cline CLI already installed."
    fi
fi

# Step 2: Copy Cline global state to DOCKER_HOME (coldstart only).
# Only globalState.json is maintained — workspace states are ephemeral defaults.
# Preserves existing user changes (only copies if target does not exist).
if [[ "${COLDSTART}" -eq 1 ]]; then
    log_log "${QUIET}" "[2/2] Setting up Cline settings ..."
    CLINE_STATE_SOURCE="${SCRIPT_DIR}/cline/globalState.json"
    CLINE_STATE_TARGET="${DOCKER_HOME}/.cline/data/globalState.json"
    if [[ -f "${CLINE_STATE_SOURCE}" ]]; then
        mkdir -p "$(dirname "${CLINE_STATE_TARGET}")"
        if [[ ! -f "${CLINE_STATE_TARGET}" ]]; then
            cp "${CLINE_STATE_SOURCE}" "${CLINE_STATE_TARGET}"
            log_log "${QUIET}" "Copied Cline global state to \`${CLINE_STATE_TARGET}\`."
        else
            log_log "${QUIET}" "Cline global state already exists. Skipping copy to preserve user changes."
        fi
    else
        echo "WARNING: Cline global state source not found at \`${CLINE_STATE_SOURCE}\`." >&2
    fi
fi

log_log "${QUIET}" "Cline CLI setup complete."