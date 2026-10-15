#!/bin/bash
# Host-side shell commands for managing the code-server container.
#
# Sourced by `rc.sh` on the host (never inside the container) on every
# platform. Provides `code-server-start` to (re)launch the detached container
# with the platform's `wrapper.sh`, e.g. after host maintenance killed it.
#
# Usage
# -----
# ```
# code-server-start          # bash ${RC_DIR}/<platform>/wrapper.sh --detach
# code-server-start --help   # print usage
# ```

# Print the usage of `code-server-start`.
#
# Returns
# -------
# (No-Returns)
_code_server_start_usage() {
    cat <<'EOF'
Usage: code-server-start [-h | --help]

Relaunch the code-server container in the background. This is a fixed alias of
`bash ${RC_DIR}/<platform>/wrapper.sh --detach`, so it takes no arguments; run
`wrapper.sh` directly to change the port or the code-server arguments.

Options:
  -h, --help    Show this help and exit.
EOF
}

# (Re)launch the code-server container in the background.
#
# Resolves the platform the same way `config.sh` does, then runs that
# platform's `wrapper.sh --detach`, which removes any stale container and
# creates a fresh one. Any argument other than `-h`/`--help` is rejected,
# because `wrapper.sh` would forward it as the container command.
#
# Args
# ----
# - `-h`, `--help`
#     Print usage and exit.
#
# Returns
# -------
# - `status`
#     Exit status of `wrapper.sh`; 0 for `--help`; 2 for any other argument;
#     1 if `RC_DIR` is unset or the platform has no detached launch mode.
code-server-start() {
    if [[ $# -gt 0 ]]; then
        if [[ $# -eq 1 && ("${1}" == "-h" || "${1}" == "--help") ]]; then
            _code_server_start_usage
            return 0
        fi
        echo "ERROR: \`code-server-start\` takes no arguments, but \"$*\" was given. Run \`code-server-start --help\` for usage." >&2
        return 2
    fi

    if [[ -z "${RC_DIR:-}" ]]; then
        echo "ERROR: \`RC_DIR\` is not set. Re-run \`home_setup.sh\` to register it in your rc file." >&2
        return 1
    fi

    local platform
    platform="$(source "${RC_DIR}/config.sh" && echo "${RC_PLATFORM}")"

    case "${platform}" in
    linux | macos)
        bash "${RC_DIR}/${platform}/wrapper.sh" --detach
        ;;
    sagemaker)
        echo "ERROR: SageMaker has no detached launch mode. Open Code Server from the JupyterLab launcher, which starts the container on demand." >&2
        return 1
        ;;
    *)
        echo "ERROR: Platform \`${platform}\` is not supported." >&2
        return 1
        ;;
    esac
}
