#!/bin/bash
# Install and check the Cline CLI.
#
# Installs the Cline CLI via npm (requires Node.js from mise). In check mode
# (default), verifies the CLI is on PATH and prints install instructions if
# missing.
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
# - Cline extension settings (API config, workspace root) are configured
#   manually on first launch — no automated config deployment.
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

# Cline CLI install location (npm into mise's active node bin directory).
# Check both HOST HOME and DOCKER_HOME since the script may run on the host
# but Cline is installed inside Docker (whose HOME = DOCKER_HOME).
_cline_bin_exists() {
    # Check mise node bin directories (host and Docker).
    local mise_node_dir=""
    if [[ -f "${MISE_INSTALL_PATH}" ]]; then
        mise_node_dir="$("${MISE_INSTALL_PATH}" where node 2>/dev/null)" || true
        if [[ -n "${mise_node_dir}" && -f "${mise_node_dir}/bin/cline" ]]; then
            return 0
        fi
    fi
    # Check XDG_DATA_HOME mise installs (covers Docker home case).
    local xdg_cline="${XDG_DATA_HOME}/mise/installs/node/${MISE_NODE_VERSION}/bin/cline"
    [[ -f "${xdg_cline}" ]] && return 0
    # Fallback: check command PATH.
    command -v cline &>/dev/null
}

# Print header.
log_log "${QUIET}" "Cline CLI Setup"

# Install or check Cline CLI.
log_log "${QUIET}" "[1/1] Checking Cline CLI ..."
if [[ "${COLDSTART}" -eq 1 ]]; then
    if _cline_bin_exists; then
        log_log "${QUIET}" "Cline CLI already installed."
    elif command -v npm &>/dev/null; then
        log_log "${QUIET}" "Installing Cline CLI via npm ..."
        npm install -g cline
    else
        echo "WARNING: \`npm\` is not available. Install Node.js first (via \`mise\`), then re-run." >&2
    fi
else
    if ! _cline_bin_exists; then
        echo "Missing \`cline\`. Run \`bash ${SCRIPT_DIR}/cline.sh --coldstart\` to install."
    else
        log_log "${QUIET}" "Cline CLI already installed."
    fi
fi

# Print completion.
log_log "${QUIET}" "Cline CLI setup complete."