#!/bin/sh
# Docker container entrypoint for interactive shells and code-server.
#
# Defaults to the configured Docker shell. When code-server flags (`--*`) are
# passed, runs code-server instead. When an explicit command is given
# (e.g., `bash`, `python3`), runs that command directly.
#
# Args
# ----
# - `$@`
#     Arguments forwarded to code-server (if flags) or the specified command.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# This allows the same Docker image to be used for both interactive terminal
# sessions (default, via `docker run -it ...`) and code-server hosting
# (via `wrapper.sh` passing `--bind-addr` etc.).
#
# Examples
# --------
# ```
# # Interactive shell mode (default).
# docker run -it image
#
# # code-server mode (flags trigger code-server).
# docker run image --bind-addr 0.0.0.0:8080
# docker run image --install-extension zokugun.sync-settings
#
# # Explicit command mode.
# docker run -it image bash
# docker run -it image python3
# ```

# No arguments: start an interactive shell (uses SHELL env var).
if [ $# -eq 0 ]; then
    exec "${SHELL:-/bin/zsh}"
fi

# First argument starts with "--": treat all arguments as code-server flags.
case "${1}" in
--*)
    exec code-server "$@"
    ;;
esac

# First argument is an explicit command: run it directly.
exec "$@"