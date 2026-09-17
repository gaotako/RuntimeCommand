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
#   `https://cli.anthropic.com/install.sh`, falling back to `npm install -g` where that
#   host does not resolve.
# - The native installer places the binary at `~/.claude/local/bin/claude`; the npm
#   fallback places it in mise's node bin directory instead.
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

# Claude Code CLI install location.
# The native installer places the binary at ~/.claude/local/bin/claude.
# `npm install -g` into mise's node places it in mise's node bin directory — NOT in
# ~/.local/bin — so that is a third install location, and it is the one that gets used
# wherever `cli.anthropic.com` does not resolve (SageMaker, cloud desktops). Every
# consumer of the binary has to know all three.
# Check both HOST HOME and DOCKER_HOME since the script may run on the host
# but Claude is installed inside Docker (whose HOME = DOCKER_HOME).
MISE_NODE_BIN_DIR="${XDG_DATA_HOME}/mise/installs/node/${MISE_NODE_VERSION}/bin"

# A `claude` merely on PATH counts only when it is NOT the ASBX toolbox build. The host's
# `~/.toolbox/` is bind-mounted into the container, so `~/.toolbox/bin/claude` answers
# `command -v claude` on the host and inside the container alike. Accepting it reports
# "already installed" while no install path holds a binary, and the missing install
# only surfaces two steps later as `register.sh: Claude Code CLI not found in container`.
_claude_bin_exists() {
    local _claude_on_path
    _claude_on_path="$(command -v claude 2>/dev/null || true)"
    [[ -f "${HOME}/.claude/local/bin/claude" ]] \
        || [[ -f "${HOME}/.local/bin/claude" ]] \
        || [[ -f "${DOCKER_HOME}/.claude/local/bin/claude" ]] \
        || [[ -f "${DOCKER_HOME}/.local/bin/claude" ]] \
        || [[ -f "${MISE_NODE_BIN_DIR}/claude" ]] \
        || [[ -n "${_claude_on_path}" && "${_claude_on_path}" != *"/.toolbox/"* ]]
}
CLAUDE_BIN="${DOCKER_HOME}/.claude/local/bin/claude"

# Print header.
log_log "${QUIET}" "Claude Code CLI Setup"

# Step 1: Install or check Claude Code CLI.
log_log "${QUIET}" "[1/2] Checking Claude Code CLI ..."
if [[ "${COLDSTART}" -eq 1 ]]; then
    if _claude_bin_exists; then
        log_log "${QUIET}" "Claude Code CLI already installed."
    else
        # Try native installer first, fall back to npm if DNS/network fails.
        # The npm-then-switch approach is necessary because SageMaker's Docker
        # network cannot resolve `cli.anthropic.com` (native installer host).
        # After npm install, `claude install` migrates to the native binary
        # and silences the npm deprecation warning.
        log_log "${QUIET}" "Installing Claude Code CLI ..."
        if curl -fsSL https://cli.anthropic.com/install.sh | sh 2>/dev/null; then
            log_log "${QUIET}" "Installed via native installer."
        elif command -v npm &>/dev/null; then
            log_log "${QUIET}" "Native installer failed. Installing via npm ..."
            npm install -g @anthropic-ai/claude-code
            # Migrate from npm to native installer to silence deprecation warning.
            if command -v claude &>/dev/null; then
                log_log "${QUIET}" "Migrating to native installer via \`claude install\` ..."
                if ! claude install 2>/dev/null; then
                    echo "WARNING: \`claude install\` migration failed. Using npm-installed version." >&2
                fi
            fi
        else
            echo "WARNING: Claude Code CLI installation failed. Neither native installer nor \`npm\` available." >&2
        fi
    fi
    # Hint to the user how to use `claude` immediately or on next session.
    # Point at the binary that actually got installed: the native installer and the npm
    # fallback land in different directories, so a fixed path names a directory that does
    # not exist whenever the fallback ran, and then no hint is printed at all.
    for _candidate in \
        "${DOCKER_HOME}/.claude/local/bin/claude" \
        "${DOCKER_HOME}/.local/bin/claude" \
        "${MISE_NODE_BIN_DIR}/claude"; do
        [[ -f "${_candidate}" ]] && CLAUDE_BIN="${_candidate}" && break
    done
    CLAUDE_BIN_DIR="$(dirname "${CLAUDE_BIN}")"
    if [[ -d "${CLAUDE_BIN_DIR}" && ":${PATH}:" != *":${CLAUDE_BIN_DIR}:"* ]]; then
        echo "PATH has been added to \`rc.sh\` for future terminal sessions."
        echo "To use \`claude\` in this session, run: \`export PATH=\"${CLAUDE_BIN_DIR}:\${PATH}\"\`."
    fi
else
    if ! _claude_bin_exists; then
        echo "Missing \`claude\`. Run \`bash ${SCRIPT_DIR}/claude.sh --coldstart\` to install."
    else
        log_log "${QUIET}" "Claude Code CLI already installed."
    fi
fi

# Step 2: Deploy Claude settings to DOCKER_HOME.
# Only deploys the template on first run (when settings.json doesn't exist).
# Once deployed, the user manages this file directly (model, Bedrock config,
# etc.). MCP server registration is handled separately by
# RuntimeCommandAmazonInternal/claude_mcp/register.sh.
log_log "${QUIET}" "[2/2] Setting up Claude settings ..."
CLAUDE_SETTINGS_SOURCE="${SCRIPT_DIR}/claude/settings.json"
CLAUDE_SETTINGS_TARGET="${DOCKER_HOME}/.claude/settings.json"
if [[ -f "${CLAUDE_SETTINGS_TARGET}" ]]; then
    log_log "${QUIET}" "Claude settings already exist at \`${CLAUDE_SETTINGS_TARGET}\`. Skipping."
elif [[ -f "${CLAUDE_SETTINGS_SOURCE}" ]]; then
    mkdir -p "$(dirname "${CLAUDE_SETTINGS_TARGET}")"

    # Export variables for envsubst.
    export DOCKER_HOME MISE_INSTALL_PATH XDG_DATA_HOME MISE_NODE_VERSION

    # Substitute variables and write the deployed settings.
    envsubst < "${CLAUDE_SETTINGS_SOURCE}" > "${CLAUDE_SETTINGS_TARGET}"
    log_log "${QUIET}" "Deployed Claude settings to \`${CLAUDE_SETTINGS_TARGET}\`."
else
    echo "WARNING: Claude settings source not found at \`${CLAUDE_SETTINGS_SOURCE}\`." >&2
fi

log_log "${QUIET}" "Claude Code CLI setup complete."