#!/bin/bash
# Shell handler detection utility.
#
# Detects the current interactive shell and provides the result in `CISH`.
# Scripts can use this to check bash compatibility or adapt behaviour.
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

# Check whether the detected shell is bash-compatible.
#
# Prints a warning to stderr if the shell is not bash or a bash-compatible
# variant. Returns 0 for bash-compatible, 1 otherwise.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# - exit code
#     `0` if bash-compatible, `1` otherwise.
shell::check_bash_compat() {
    case "${CISH}" in
    *bash*)
        return 0
        ;;
    *sh*)
        echo "WARNING: Current shell '${CISH}' may not be fully bash-compatible. Some features may not work." >&2
        return 0
        ;;
    *)
        echo "WARNING: Detected non-bash shell '${CISH}'. Scripts require bash to function correctly." >&2
        return 1
        ;;
    esac
}