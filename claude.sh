#!/bin/bash
# Install and configure Claude Code CLI.
#
# Installs the Claude Code CLI via the native installer and copies the Claude
# settings file to the Docker home directory.
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
# - Claude Code CLI is installed via the native installer from
#   `https://cli.anthropic.com/install.sh`.
# - The binary is placed at `~/.claude/local/bin/claude`.
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

# Claude Code CLI install location (native installer default).
CLAUDE_BIN="${HOME}/.claude/local/bin/claude"

# Print header.
log_log "${QUIET}" "Claude Code CLI Setup"

# Step 1: Install or check Claude Code CLI.
log_log "${QUIET}" "[1/2] Checking Claude Code CLI ..."
if [[ "${COLDSTART}" -eq 1 ]]; then
    if [[ -f "${CLAUDE_BIN}" ]]; then
        log_log "${QUIET}" "Claude Code CLI already installed at \`${CLAUDE_BIN}\`."
    else
        log_log "${QUIET}" "Installing Claude Code CLI via native installer ..."
        curl -fsSL https://cli.anthropic.com/install.sh | sh
    fi
    # Hint to the user how to use `claude` immediately or on next session.
    CLAUDE_BIN_DIR="$(dirname "${CLAUDE_BIN}")"
    if [[ -d "${CLAUDE_BIN_DIR}" && ":${PATH}:" != *":${CLAUDE_BIN_DIR}:"* ]]; then
        echo "PATH has been added to \`rc.sh\` for future terminal sessions."
        echo "To use \`claude\` in this session, run: \`export PATH=\"${CLAUDE_BIN_DIR}:\${PATH}\"\`."
    fi
else
    if [[ ! -f "${CLAUDE_BIN}" ]] && ! command -v claude &>/dev/null; then
        echo "Missing \`claude\`. Run \`bash ${SCRIPT_DIR}/claude.sh --coldstart\` to install."
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