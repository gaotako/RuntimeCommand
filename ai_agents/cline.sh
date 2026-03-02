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
# - The global state template (`cline/globalState-template.json`) contains
#   `${WORKSPACE}` placeholders resolved via `sed` at setup time. The resolved
#   file is copied or merged into `DOCKER_HOME/.cline/data/globalState.json`.
# - If the target already exists (e.g., Cline extension wrote defaults on
#   first activation), our settings are merged on top — preserving extension
#   keys while ensuring API config and workspace root are applied.
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

# Fix Cline workspace root if it points to Desktop (invalid default).
#
# Checks the existing `globalState.json` for `"Desktop"` in workspace roots.
# If found, resolves the template and merges corrected paths on top.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)
_rc_fix_cline_desktop_root() {
    CLINE_STATE_TARGET="${DOCKER_HOME}/.cline/data/globalState.json"
    if [[ -f "${CLINE_STATE_TARGET}" ]] && grep -q '"Desktop"' "${CLINE_STATE_TARGET}" 2>/dev/null; then
        echo "Cline workspace root is set to \`Desktop\` (invalid). Fixing to \`Workspace\` ..."
        CLINE_STATE_TEMPLATE="${SCRIPT_DIR}/cline/globalState-template.json"
        if [[ -f "${CLINE_STATE_TEMPLATE}" ]]; then
            CLINE_STATE_RESOLVED="$(mktemp)"
            WORKSPACE_SED="$(echo "${WORKSPACE}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
            sed -e "s/\${WORKSPACE}/${WORKSPACE_SED}/g" \
                "${CLINE_STATE_TEMPLATE}" > "${CLINE_STATE_RESOLVED}"
            python3 "${PROJECT_ROOT}/pyutils/json_merge.py" \
                "${CLINE_STATE_RESOLVED}" "${CLINE_STATE_TARGET}"
            rm -f "${CLINE_STATE_RESOLVED}"
            echo "Fixed. Restart code-server to apply."
        fi
    fi
}

# Resolve `${WORKSPACE}` in the template and copy/merge into DOCKER_HOME.
#
# Creates a temporary resolved copy of `globalState-template.json` with
# `${WORKSPACE}` replaced by the actual workspace path. If the target does
# not exist, copies the resolved file. If it exists, merges our keys on top
# via `json_merge.py` — preserving extension-written keys while ensuring
# API config and workspace root are applied.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)
_rc_deploy_cline_state() {
    CLINE_STATE_TEMPLATE="${SCRIPT_DIR}/cline/globalState-template.json"
    CLINE_STATE_TARGET="${DOCKER_HOME}/.cline/data/globalState.json"

    if [[ ! -f "${CLINE_STATE_TEMPLATE}" ]]; then
        echo "WARNING: Cline global state template not found at \`${CLINE_STATE_TEMPLATE}\`." >&2
        return
    fi

    mkdir -p "$(dirname "${CLINE_STATE_TARGET}")"
    CLINE_STATE_RESOLVED="$(mktemp)"
    WORKSPACE_SED="$(echo "${WORKSPACE}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
    sed -e "s/\${WORKSPACE}/${WORKSPACE_SED}/g" \
        "${CLINE_STATE_TEMPLATE}" > "${CLINE_STATE_RESOLVED}"

    if [[ ! -f "${CLINE_STATE_TARGET}" ]]; then
        cp "${CLINE_STATE_RESOLVED}" "${CLINE_STATE_TARGET}"
        log_log "${QUIET}" "Copied Cline global state to \`${CLINE_STATE_TARGET}\`."
    else
        python3 "${PROJECT_ROOT}/pyutils/json_merge.py" \
            "${CLINE_STATE_RESOLVED}" "${CLINE_STATE_TARGET}"
        log_log "${QUIET}" "Merged Cline settings into existing \`${CLINE_STATE_TARGET}\`."
    fi

    rm -f "${CLINE_STATE_RESOLVED}"
}

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

    # Fix Cline workspace root if it points to Desktop (invalid default).
    _rc_fix_cline_desktop_root
fi

# Resolve template `${WORKSPACE}` and merge Cline global state (coldstart only).
if [[ "${COLDSTART}" -eq 1 ]]; then
    log_log "${QUIET}" "[2/2] Setting up Cline settings ..."
    _rc_deploy_cline_state
fi

log_log "${QUIET}" "Cline CLI setup complete."