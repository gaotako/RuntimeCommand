#!/bin/bash
# Install and configure Claude Code CLI.
#
# Installs the Claude Code CLI via npm (requires Node.js from mise) and
# copies the Claude settings file to the Docker home directory.
#
# Args
# ----
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--coldstart`
#     When set, installs Claude Code CLI from scratch. Without this flag
#     the script checks for missing dependencies and prints install
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
# - Claude Code CLI is installed globally via `npm install -g`.
# - Node.js must be available (installed by mise) before running this script
#   in `--coldstart` mode.
# - The Claude settings file is copied from `claude/settings.json` in the
#   project directory to `DOCKER_HOME/.claude/settings.json`.
#
# Examples
# --------
# ```
# bash claude.sh --coldstart
# bash claude.sh --coldstart --log-depth 2
# bash claude.sh --quiet
# bash claude.sh
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

# Print header.
log_log "${QUIET}" "Claude Code CLI Setup"

# Step 1: Install or check Claude Code CLI.
log_log "${QUIET}" "[1/2] Checking Claude Code CLI ..."
if [[ "${COLDSTART}" -eq 1 ]]; then
    if command -v npm &>/dev/null; then
        log_log "${QUIET}" "Installing Claude Code CLI via npm ..."
        npm install -g @anthropic-ai/claude-code
    else
        log_log "${QUIET}" "WARNING: \`npm\` is not available. Install Node.js first (via \`mise\`), then re-run."
    fi
else
    if ! command -v claude &>/dev/null; then
        echo "Missing claude, run \`bash ${SCRIPT_DIR}/claude.sh --coldstart\` to install."
    else
        log_log "${QUIET}" "Claude Code CLI already installed."
    fi
fi

# Step 2: Copy Claude settings to DOCKER_HOME.
log_log "${QUIET}" "[2/2] Setting up Claude settings ..."
CLAUDE_SETTINGS_SOURCE="${SCRIPT_DIR}/claude/settings.json"
CLAUDE_SETTINGS_TARGET="${DOCKER_HOME}/.claude/settings.json"
if [[ -f "${CLAUDE_SETTINGS_SOURCE}" ]]; then
    mkdir -p "$(dirname "${CLAUDE_SETTINGS_TARGET}")"
    cp "${CLAUDE_SETTINGS_SOURCE}" "${CLAUDE_SETTINGS_TARGET}"
    log_log "${QUIET}" "Copied Claude settings to \`${CLAUDE_SETTINGS_TARGET}\`."
else
    log_log "${QUIET}" "WARNING: Claude settings source not found at \`${CLAUDE_SETTINGS_SOURCE}\`."
fi

log_log "${QUIET}" "Claude Code CLI setup complete."