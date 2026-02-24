#!/bin/bash
# Shell handler detection and project root resolution.
#
# Detects the current interactive shell (`CISH`) and resolves the project
# root directory (`RC_DIR`) from this file's location. Scripts can use
# `CISH` to adapt behaviour per shell and `RC_DIR` to locate project files.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)

# Prevent redundant sourcing.
[[ ${_SHUTILS_SHELL_SH_LOADED:-0} -eq 1 ]] && return
_SHUTILS_SHELL_SH_LOADED=1

# Detect the current interactive shell handler.
CISH="$(ps -o comm -p $$ | tail -1 | cut -d " " -f 1)"

# Resolve the project root directory from this file's location.
# shell.sh lives at docker/shutils/shell.sh, so RC_DIR = docker/.
# In zsh, ${0:a:h} gives the caller's path when sourced; ${(%):-%x}
# reliably returns the actual sourced file's path.
case "${CISH}" in
*bash*|*sh*)
    RC_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
    ;;
*zsh*)
    RC_DIR="${${(%):-%x}:a:h:h}"
    ;;
*)
    RC_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
    ;;
esac

# Check whether the detected shell supports extended features.
#
# Bash and zsh support extended features required by the codebase: arrays,
# `declare -g`, `${var^^}` parameter expansion, C-style arithmetic, etc.
# Plain sh (e.g., dash on Ubuntu) is POSIX-only and lacks these features.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# - exit code
#     `0` if the shell supports extended features (bash or zsh), `1` otherwise.
shell_check_ext_compat() {
    case "${CISH}" in
    *bash*)
        return 0
        ;;
    *zsh*)
        return 0
        ;;
    *sh*)
        echo "WARNING: Current shell '${CISH}' is POSIX-only and lacks extended features. Scripts require bash or zsh." >&2
        return 1
        ;;
    *)
        echo "WARNING: Detected unsupported shell '${CISH}'. Scripts require bash or zsh." >&2
        return 1
        ;;
    esac
}