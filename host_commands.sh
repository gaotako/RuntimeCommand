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
# code-server-start               # bash ${RC_DIR}/<platform>/wrapper.sh --detach
# code-server-start --port 9090   # extra args are forwarded to wrapper.sh
# ```

# (Re)launch the code-server container in the background.
#
# Resolves the platform the same way `config.sh` does, then runs that
# platform's `wrapper.sh --detach`, which removes any stale container and
# creates a fresh one.
#
# Args
# ----
# - `$@`
#     Additional arguments forwarded to `wrapper.sh` (e.g., `--port 9090`).
#
# Returns
# -------
# - `status`
#     Exit status of `wrapper.sh`; 1 if `RC_DIR` is unset or the platform has
#     no detached launch mode.
code-server-start() {
    if [[ -z "${RC_DIR:-}" ]]; then
        echo "ERROR: \`RC_DIR\` is not set. Re-run \`home_setup.sh\` to register it in your rc file." >&2
        return 1
    fi

    # Resolve the platform in a subshell so config.sh does not leak variables.
    local platform
    platform="$(source "${RC_DIR}/config.sh" && echo "${RC_PLATFORM}")"

    case "${platform}" in
    linux | macos)
        bash "${RC_DIR}/${platform}/wrapper.sh" --detach "$@"
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
