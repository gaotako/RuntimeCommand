#!/bin/bash
# Install and configure the Codex CLI.
#
# Installs the Codex CLI via the standalone installer and copies the Codex
# config file to the Docker home directory.
#
# Args
# ----
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--coldstart`
#     When set, installs Codex CLI from scratch. Without this flag the script
#     checks for the binary and prints install instructions.
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
# - Codex CLI is installed via `curl -fsSL https://chatgpt.com/codex/install.sh | sh`,
#   falling back to `npm install -g @openai/codex` where that host does not resolve.
# - The standalone installer places the binary at `~/.local/bin/codex` and its release
#   files under `~/.codex/packages/standalone/`; the npm fallback places it in mise's
#   node bin directory instead.
# - The config file is copied from `codex/config.toml` in the project directory to
#   `DOCKER_HOME/.codex/config.toml`. It routes inference through the built-in
#   `amazon-bedrock` provider with the `default` AWS profile, matching the Claude
#   settings template.
#
# Examples
# --------
# ```
# bash codex.sh --coldstart
# bash codex.sh --coldstart --log-depth 2
# bash codex.sh --quiet
# bash codex.sh
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

# Codex CLI install locations.
# The standalone installer writes ~/.local/bin/codex; the npm fallback writes mise's
# node bin directory. Check both HOST HOME and DOCKER_HOME since the script may run on
# the host but Codex is installed inside Docker (whose HOME = DOCKER_HOME).
# A `codex` merely on PATH counts only when it is NOT the ASBX toolbox build, for the
# same reason as in `claude.sh`: the host's `~/.toolbox/` is bind-mounted into the
# container, so `~/.toolbox/bin/codex` answers `command -v codex` in both places.
MISE_NODE_BIN_DIR="${XDG_DATA_HOME}/mise/installs/node/${MISE_NODE_VERSION}/bin"
_codex_bin_exists() {
    local _codex_on_path
    _codex_on_path="$(command -v codex 2>/dev/null || true)"
    [[ -f "${HOME}/.local/bin/codex" ]] \
        || [[ -f "${DOCKER_HOME}/.local/bin/codex" ]] \
        || [[ -f "${MISE_NODE_BIN_DIR}/codex" ]] \
        || [[ -n "${_codex_on_path}" && "${_codex_on_path}" != *"/.toolbox/"* ]]
}
CODEX_BIN="${DOCKER_HOME}/.local/bin/codex"

# Print header.
log_log "${QUIET}" "Codex CLI Setup"

# Step 1: Install or check Codex CLI.
log_log "${QUIET}" "[1/2] Checking Codex CLI ..."
if [[ "${COLDSTART}" -eq 1 ]]; then
    if _codex_bin_exists; then
        log_log "${QUIET}" "Codex CLI already installed."
    else
        log_log "${QUIET}" "Installing Codex CLI ..."
        if curl -fsSL https://chatgpt.com/codex/install.sh | sh; then
            log_log "${QUIET}" "Installed via standalone installer."
        elif command -v npm &>/dev/null; then
            log_log "${QUIET}" "Standalone installer failed. Installing via npm ..."
            npm install -g @openai/codex
        else
            echo "WARNING: Codex CLI installation failed. Neither the standalone installer nor \`npm\` is available." >&2
        fi
    fi
    # Hint to the user how to use `codex` immediately or on next session.
    for _candidate in "${DOCKER_HOME}/.local/bin/codex" "${MISE_NODE_BIN_DIR}/codex"; do
        [[ -f "${_candidate}" ]] && CODEX_BIN="${_candidate}" && break
    done
    CODEX_BIN_DIR="$(dirname "${CODEX_BIN}")"
    if [[ -d "${CODEX_BIN_DIR}" && ":${PATH}:" != *":${CODEX_BIN_DIR}:"* ]]; then
        echo "PATH has been added to \`rc.sh\` for future terminal sessions."
        echo "To use \`codex\` in this session, run: \`export PATH=\"${CODEX_BIN_DIR}:\${PATH}\"\`."
    fi
else
    if ! _codex_bin_exists; then
        echo "Missing \`codex\`. Run \`bash ${SCRIPT_DIR}/codex.sh --coldstart\` to install."
    else
        log_log "${QUIET}" "Codex CLI already installed."
    fi
fi

# Step 2: Deploy Codex config to DOCKER_HOME.
# Only deploys the template on first run (when config.toml doesn't exist).
# Once deployed, the user manages this file directly (model, Bedrock config,
# etc.). MCP server registration is handled separately by
# RuntimeCommandAmazonInternal/claude_mcp/register.sh.
log_log "${QUIET}" "[2/2] Setting up Codex config ..."
CODEX_CONFIG_SOURCE="${SCRIPT_DIR}/codex/config.toml"
CODEX_CONFIG_TARGET="${DOCKER_HOME}/.codex/config.toml"
if [[ -f "${CODEX_CONFIG_TARGET}" ]]; then
    log_log "${QUIET}" "Codex config already exists at \`${CODEX_CONFIG_TARGET}\`. Skipping."
elif [[ -f "${CODEX_CONFIG_SOURCE}" ]]; then
    mkdir -p "$(dirname "${CODEX_CONFIG_TARGET}")"
    cp "${CODEX_CONFIG_SOURCE}" "${CODEX_CONFIG_TARGET}"
    log_log "${QUIET}" "Deployed Codex config to \`${CODEX_CONFIG_TARGET}\`."
else
    echo "WARNING: Codex config source not found at \`${CODEX_CONFIG_SOURCE}\`." >&2
fi

log_log "${QUIET}" "Codex CLI setup complete."
