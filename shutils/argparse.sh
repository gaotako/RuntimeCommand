#!/bin/bash
# Shared argument parsing library for docker scripts.
#
# Provides `argparse_parse` which dynamically translates `--key value`
# arguments into shell variables and collects positional arguments.
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
# source shutils/argparse.sh
# argparse_parse "$@"
# # --my-key value becomes MY_KEY=value
# # --my-key=value becomes MY_KEY=value
# # --my-flag (no value) becomes MY_FLAG=1
# # positional args are in POSITIONAL_ARGS array
# ```

# Prevent redundant sourcing.
[[ ${_SHUTILS_ARGPARSE_SH_LOADED:-0} -eq 1 ]] && return
_SHUTILS_ARGPARSE_SH_LOADED=1

# Parse command-line arguments into variables.
#
# Keyword arguments are converted to uppercase shell variables with hyphens
# replaced by underscores. Supports two forms:
# - `--key value` (value must not start with `--`).
# - `--key=value` (unambiguous, use when value starts with `--`).
# Boolean flags (`--flag` without a following value) are set to `1`.
# Positional arguments are collected into the `POSITIONAL_ARGS` array.
#
# Args
# ----
# - $@
#     Raw command-line arguments to parse.
#
# Returns
# -------
# - POSITIONAL_ARGS
#     Array of positional (non-keyword) arguments. To restore `$1`, `$2`,
#     etc., run `set -- "${POSITIONAL_ARGS[@]}"` after calling this function.
#     Otherwise, use `POSITIONAL_ARGS[0]`, `POSITIONAL_ARGS[1]`, etc.
argparse_parse() {
    POSITIONAL_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "${1}" in
        --*=*)
            local key="${1%%=*}"
            local value="${1#*=}"
            key="${key#--}"
            key="${key//-/_}"
            key="${key^^}"
            declare -g "${key}"="${value}"
            shift 1
            ;;
        --*)
            local key="${1#--}"
            key="${key//-/_}"
            key="${key^^}"
            if [[ $# -ge 2 && "${2}" != --* ]]; then
                declare -g "${key}"="${2}"
                shift 2
            else
                declare -g "${key}"=1
                shift 1
            fi
            ;;
        *)
            POSITIONAL_ARGS+=("${1}")
            shift 1
            ;;
        esac
    done
}