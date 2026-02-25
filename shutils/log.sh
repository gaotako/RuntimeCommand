#!/bin/bash
# Shared logging library for docker scripts.
#
# Provides `log_make_indent` to build a BuildKit-style log indent prefix
# from a numeric depth value, and `log_log` to print indented messages
# with optional quiet suppression.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)
#
# Examples
# --------
# ```
# source shutils/log.sh
# log_make_indent 1  # LOG_INDENT="=>"
# log_make_indent 2  # LOG_INDENT="=> =>"
# log_log 0 "Hello"  # prints "=> Hello"
# log_log 1 "Hello"  # prints nothing (quiet=1)
# ```

# Prevent redundant sourcing.
[[ ${_SHUTILS_LOG_SH_LOADED:-0} -eq 1 ]] && return
_SHUTILS_LOG_SH_LOADED=1

# Logging depth defaults.
LOG_DEPTH_DEFAULT=1
LOG_DEPTH="${LOG_DEPTH:-${LOG_DEPTH_DEFAULT}}"

# Build a BuildKit-style log indent prefix from a numeric depth.
#
# Repeats `"=>"` the given number of times, separated by spaces.
# The result is stored in the global variable `LOG_INDENT`.
#
# Args
# ----
# - `depth`
#     Nesting depth (must be >= 1).
#
# Returns
# -------
# - `LOG_INDENT`
#     The constructed indent string (e.g., `"=> =>"` for depth 2).
log_make_indent() {
    local depth="${1}"
    LOG_INDENT=""
    local i
    for ((i = 0; i < depth; i++)); do
        LOG_INDENT="${LOG_INDENT}=>"
        if ((i < depth - 1)); then
            LOG_INDENT="${LOG_INDENT} "
        fi
    done
}

# Print a log message with the current indent prefix.
#
# When `quiet` is `1`, the message is suppressed. Otherwise, the message
# is printed prefixed with `LOG_INDENT`.
#
# Args
# ----
# - `quiet`
#     `0` to print, `1` to suppress.
# - `message`
#     The message to print.
#
# Returns
# -------
# (No-Returns)
log_log() {
    local quiet="${1}"
    local message="${2}"
    [[ "${quiet}" -eq 1 ]] && return
    echo "${LOG_INDENT} ${message}"
}