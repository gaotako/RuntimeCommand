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

# Bootstrap: locate this file to find shutils/shell.sh.
# After sourcing shell.sh, RC_DIR and CISH are available globally.
case "$(ps -o comm -p $$ | tail -1 | cut -d " " -f 1)" in
*bash*|*sh*)
    _rc_self="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
    ;;
*zsh*)
    _rc_self="${0:a:h}"
    ;;
*)
    _rc_self="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
    ;;
esac

# Source shell handler detection (provides CISH and RC_DIR).
source "${_rc_self}/shutils/shell.sh"
shell_check_ext_compat

# Guard: only run inside the Docker container launched by wrapper.sh.
# wrapper.sh sets RC_DOCKER=1 as a container env var (and unsets it on the
# host before launching). On the SageMaker host or any other environment,
# rc.sh exits early without modifying the shell.
if [[ "${RC_DOCKER:-0}" != "1" ]]; then
    return 0 2>/dev/null || true
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

# ANSI color codes for terminal output.
export PSC_ASCII_RESET=$'\e[0m'
export PSC_ASCII_RED=$'\e[31m'
export PSC_ASCII_GREEN=$'\e[32m'
export PSC_ASCII_YELLOW=$'\e[33m'
export PSC_ASCII_BLUE=$'\e[34m'
export PSC_ASCII_CYAN=$'\e[35m'
export PSC_ASCII_MAGENTA=$'\e[36m'
export PSC_ASCII_BRIGHT_RED=$'\e[91m'
export PSC_ASCII_BRIGHT_GREEN=$'\e[92m'
export PSC_ASCII_BRIGHT_YELLOW=$'\e[93m'
export PSC_ASCII_BRIGHT_BLUE=$'\e[94m'
export PSC_ASCII_BRIGHT_CYAN=$'\e[95m'
export PSC_ASCII_BRIGHT_MAGENTA=$'\e[96m'
export PSC_ASCII_NEWLINE=$'\n'

# Set the shell prompt based on the detected shell handler.
case "${CISH}" in
*bash*|*sh*)
    shopt -s promptvars 2>/dev/null
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}\#${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}\u${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}\h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}\w${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}\W${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*zsh*)
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}%h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}%n${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}%m${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}%~${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}%c${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*)
    CLI_HEADER="#\# \u@\h:\w|\W"
    export PS1="${PSC_ASCII_NEWLINE}${CLI_HEADER}${PSC_ASCII_NEWLINE}$ "
    ;;
esac

# Set up mise (polyglot runtime manager).
# Delegates to mise.sh which handles migration, activation, settings, and
# runtime checks. Migration must happen before activation to avoid
# "untrusted config" errors from stale files in ~/.config/mise/.
bash "${RC_DIR}/mise.sh"

# Activate mise for the current shell session if the binary is present.
if [[ -f "${MISE_INSTALL_PATH}" ]]; then
    case "${CISH}" in
    *bash*|*sh*)
        eval "$("${MISE_INSTALL_PATH}" activate bash)"
        ;;
    *zsh*)
        eval "$("${MISE_INSTALL_PATH}" activate zsh)"
        ;;
    *)
        echo "WARNING: Unknown shell '${CISH}', mise is not activated." >&2
        ;;
    esac
fi
