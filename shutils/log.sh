#!/bin/bash
# Shared logging library for docker scripts.
#
# Provides `log::make_indent` to build a BuildKit-style log indent prefix
# from a numeric depth value.
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
# log::make_indent 1  # LOG_INDENT="=>"
# log::make_indent 2  # LOG_INDENT="=> =>"
# log::make_indent 3  # LOG_INDENT="=> => =>"
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
# - depth
#     Nesting depth (must be >= 1).
#
# Returns
# -------
# - LOG_INDENT
#     The constructed indent string (e.g., `"=> =>"` for depth 2).
log::make_indent() {
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