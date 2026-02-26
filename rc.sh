#!/bin/bash
# Shell-agnostic runtime command initialization for Docker code-server.
#
# Sourced on every interactive shell session inside the container.
# Exports all environment variables from config.sh, sets up ANSI color
# codes, persistent path variables, the shell prompt, and mise activation.
# Supports bash and zsh via `CISH` detection from `shell.sh`.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)

# Guard: only run inside the Docker container launched by wrapper.sh.
# wrapper.sh sets RC_DOCKER=1 as a container env var (and unsets it on the
# host before launching). On the SageMaker host or any other environment,
# rc.sh shows docker entry instructions (once) and exits early.
if [[ "${RC_DOCKER:-0}" != "1" ]]; then
    # Check if the lifecycle setup has completed.
    # APP_DATA_HOME may not be set yet (config.sh not sourced), so derive it.
    _RC_APP_DATA="${HOME}/SageMaker/Application/data"
    _RC_READY_FLAG="${_RC_APP_DATA}/.rc_ready"
    if [[ ! -f "${_RC_READY_FLAG}" ]]; then
        if [[ "${_RC_NOT_READY_SHOWN:-0}" != "1" ]]; then
            _RC_NOT_READY_SHOWN=1
            echo "Code Server is configuring. Check \`~/SageMaker/lifecycle-create.log\` (first boot) or \`~/SageMaker/lifecycle-start.log\` (restart) to monitor progress."
        fi
        return 0 2>/dev/null || true
    fi
    if [[ "${_RC_DOCKER_HINT_SHOWN:-0}" != "1" ]]; then
        _RC_DOCKER_HINT_SHOWN=1
        echo "To enter Docker environment, run: \`docker exec -it code-server-sagemaker /bin/zsh\`."
    fi
    return 0 2>/dev/null || true
fi

# RC_DIR is set by the rc file (.zshrc/.bashrc) that sources this script.
# home_setup.sh writes `export RC_DIR="..."` before the `source rc.sh` line,
# avoiding unreliable shell-specific path detection.
if [[ -z "${RC_DIR:-}" ]]; then
    echo "ERROR: \`RC_DIR\` is not set. \`rc.sh\` must be sourced from a file that sets \`RC_DIR\`." >&2
    return 1 2>/dev/null || true
fi

# Source shell handler detection (provides CISH).
source "${RC_DIR}/shutils/shell.sh"
shell_check_ext_compat || true

# Resolve the effective shell for prompt and activation.
# Falls back to SHELL env var if CISH detection gave unexpected results.
_RC_SHELL="${CISH}"
if [[ "${_RC_SHELL}" != *bash* && "${_RC_SHELL}" != *zsh* && "${_RC_SHELL}" != *sh* ]]; then
    _RC_SHELL="${SHELL:-/bin/bash}"
fi

# Export all shared environment variables (HOME, WORKSPACE, XDG paths, etc.).
set -a
source "${RC_DIR}/config.sh"
set +a

# Export RC_ROOT (equivalent to RuntimeCommand's RC_ROOT).
export RC_ROOT="${RC_DIR}"

# Export persistent storage paths for SSH and AWS.
PERSISTENT_ROOT="$(cd "${RC_DIR}/../.." && pwd)"
export SSH_HOME="${PERSISTENT_ROOT}/ssh"
export AWS_HOME="${PERSISTENT_ROOT}/aws"

# ANSI color codes for terminal output (raw, for echo/printf).
export PSC_ASCII_RESET=$'\e[0m'
export PSC_ASCII_RED=$'\e[31m'
export PSC_ASCII_GREEN=$'\e[32m'
export PSC_ASCII_YELLOW=$'\e[33m'
export PSC_ASCII_BLUE=$'\e[34m'
export PSC_ASCII_CYAN=$'\e[36m'
export PSC_ASCII_MAGENTA=$'\e[35m'
export PSC_ASCII_BRIGHT_RED=$'\e[91m'
export PSC_ASCII_BRIGHT_GREEN=$'\e[92m'
export PSC_ASCII_BRIGHT_YELLOW=$'\e[93m'
export PSC_ASCII_BRIGHT_BLUE=$'\e[94m'
export PSC_ASCII_BRIGHT_CYAN=$'\e[96m'
export PSC_ASCII_BRIGHT_MAGENTA=$'\e[95m'
export PSC_ASCII_NEWLINE=$'\n'

# Prompt-safe color codes (wrapped for the detected shell).
# bash uses \[...\] to mark non-printing characters in PS1.
# zsh uses %{...%} to mark non-printing characters in PS1.
# zsh case must come before *sh* because "zsh" contains "sh".
case "${_RC_SHELL}" in
*zsh*)
    _PS_RESET="%{${PSC_ASCII_RESET}%}"
    _PS_CYAN="%{${PSC_ASCII_CYAN}%}"
    _PS_GREEN="%{${PSC_ASCII_BRIGHT_GREEN}%}"
    _PS_BLUE="%{${PSC_ASCII_BRIGHT_BLUE}%}"
    _PS_YELLOW="%{${PSC_ASCII_YELLOW}%}"
    _PS_BYELLOW="%{${PSC_ASCII_BRIGHT_YELLOW}%}"
    ;;
*bash*|*sh*)
    _PS_RESET="\[${PSC_ASCII_RESET}\]"
    _PS_CYAN="\[${PSC_ASCII_CYAN}\]"
    _PS_GREEN="\[${PSC_ASCII_BRIGHT_GREEN}\]"
    _PS_BLUE="\[${PSC_ASCII_BRIGHT_BLUE}\]"
    _PS_YELLOW="\[${PSC_ASCII_YELLOW}\]"
    _PS_BYELLOW="\[${PSC_ASCII_BRIGHT_YELLOW}\]"
    ;;
*)
    _PS_RESET=""
    _PS_CYAN=""
    _PS_GREEN=""
    _PS_BLUE=""
    _PS_YELLOW=""
    _PS_BYELLOW=""
    ;;
esac

# Set the shell prompt based on the effective shell.
# zsh case must come before *sh* because "zsh" contains "sh".
case "${_RC_SHELL}" in
*zsh*)
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${_PS_CYAN}%h${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER} ${_PS_GREEN}%n${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER}@${_PS_BLUE}%m${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER}:${_PS_YELLOW}%~${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER}|${_PS_BYELLOW}%c${_PS_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${_PS_RESET}${CLI_HEADER}${_PS_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*bash*|*sh*)
    shopt -s promptvars 2>/dev/null
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${_PS_CYAN}\#${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER} ${_PS_GREEN}\u${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER}@${_PS_BLUE}\h${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER}:${_PS_YELLOW}\w${_PS_RESET}"
    CLI_HEADER="${CLI_HEADER}|${_PS_BYELLOW}\W${_PS_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${_PS_RESET}${CLI_HEADER}${_PS_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*)
    CLI_HEADER="#\# \u@\h:\w|\W"
    export PS1="${PSC_ASCII_NEWLINE}${CLI_HEADER}${PSC_ASCII_NEWLINE}$ "
    ;;
esac

# Set up mise (polyglot runtime manager).
# Uses --quiet to suppress step logs during shell startup; only "Missing ..."
# messages are printed.
bash "${RC_DIR}/mise.sh" --quiet

# Check AI agent CLI availability.
# Uses --quiet to suppress step logs; only "Missing ..." messages are printed.
bash "${RC_DIR}/ai_agents/claude.sh" --quiet
bash "${RC_DIR}/ai_agents/cline.sh" --quiet
bash "${RC_DIR}/ai_agents/kiro.sh" --quiet

# Add CLI tool paths to PATH if present.
if [[ -d "${HOME}/.claude/local/bin" && ":${PATH}:" != *":${HOME}/.claude/local/bin:"* ]]; then
    export PATH="${HOME}/.claude/local/bin:${PATH}"
fi
if [[ -d "${HOME}/.local/bin" && ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi

# Activate mise for the current shell session if the binary is present.
if [[ -f "${MISE_INSTALL_PATH}" ]]; then
    case "${_RC_SHELL}" in
    *zsh*)
        eval "$("${MISE_INSTALL_PATH}" activate zsh)"
        ;;
    *bash*|*sh*)
        eval "$("${MISE_INSTALL_PATH}" activate bash)"
        ;;
    *)
        echo "WARNING: Unknown shell \`${_RC_SHELL}\`. \`mise\` is not activated." >&2
        ;;
    esac
fi