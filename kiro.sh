#!/bin/bash
# Install and configure the Kiro CLI.
#
# Installs the Kiro CLI via the official installer script and adds the
# binary to PATH.
#
# Args
# ----
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--coldstart`
#     When set, installs Kiro CLI from scratch. Without this flag the
#     script checks for the binary and prints install instructions.
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
# - Kiro CLI is installed via `curl -fsSL https://cli.kiro.dev/install | bash`.
# - The binary is placed at `~/.local/bin/kiro` by default.
#
# Examples
# --------
# ```
# bash kiro.sh --coldstart
# bash kiro.sh --coldstart --log-depth 2
# bash kiro.sh --quiet
# bash kiro.sh
# ```
set -euo pipefail

# Resolve directory paths.
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source shared libraries and defaults.
source "${SCRIPT_DIR}/shutils/argparse.sh"
source "${SCRIPT_DIR}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH, COLDSTART, QUIET via argparse).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared defaults (provides DOCKER_HOME, MISE_INSTALL_PATH, etc.).
source "${SCRIPT_DIR}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve flags from argparse (--coldstart sets COLDSTART=1, --quiet sets QUIET=1).
COLDSTART_DEFAULT=0
COLDSTART="${COLDSTART:-${COLDSTART_DEFAULT}}"
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"

# Kiro CLI install location (default installer path).
KIRO_BIN="${HOME}/.local/bin/kiro"

# Print header.
log_log "${QUIET}" "Kiro CLI Setup"

# Install or check Kiro CLI.
log_log "${QUIET}" "[1/1] Checking Kiro CLI ..."
if [[ "${COLDSTART}" -eq 1 ]]; then
    if [[ -f "${KIRO_BIN}" ]]; then
        log_log "${QUIET}" "Kiro CLI already installed at \`${KIRO_BIN}\`."
    else
        log_log "${QUIET}" "Installing Kiro CLI via official installer ..."
        curl -fsSL https://cli.kiro.dev/install | bash
    fi
    # Hint to the user how to use `kiro` immediately or on next session.
    KIRO_BIN_DIR="$(dirname "${KIRO_BIN}")"
    if [[ -d "${KIRO_BIN_DIR}" && ":${PATH}:" != *":${KIRO_BIN_DIR}:"* ]]; then
        echo "PATH has been added to \`rc.sh\` for future terminal sessions."
        echo "To use \`kiro\` in this session, run: \`export PATH=\"${KIRO_BIN_DIR}:\${PATH}\"\`."
    fi
else
    if [[ ! -f "${KIRO_BIN}" ]] && ! command -v kiro &>/dev/null; then
        echo "Missing \`kiro\`. Run \`bash ${SCRIPT_DIR}/kiro.sh --coldstart\` to install."
    else
        log_log "${QUIET}" "Kiro CLI already installed."
    fi
fi

log_log "${QUIET}" "Kiro CLI setup complete."