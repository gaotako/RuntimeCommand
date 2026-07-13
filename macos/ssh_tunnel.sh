#!/bin/bash
# SSH tunnel helper for forwarding remote code-server to local macOS.
#
# Provides `code-server-tunnel` as a generic command for creating SSH
# port-forwarding tunnels to any remote host running code-server.
#
# Usage
# -----
# ```
# code-server-tunnel user@host.example.com          # forwards 8080 → localhost:8081
# code-server-tunnel user@host.example.com 8082     # forwards 8080 → localhost:8082
# code-server-tunnel --kill user@host.example.com   # kills the tunnel
# code-server-tunnel --list                         # shows active tunnels
# ```

# Default remote port (code-server inside Docker on remote host).
_CS_TUNNEL_REMOTE_PORT=8080

# Default local port.
_CS_TUNNEL_LOCAL_PORT_DEFAULT=8081

# SSH tunnel for code-server on a remote host.
#
# Creates a background SSH tunnel forwarding a remote code-server port
# to a local port.
#
# Args
# ----
# - `--kill HOST`
#     Kill an existing tunnel for the given host.
# - `--list`
#     List active code-server SSH tunnels.
# - `HOST`
#     Full SSH host (e.g., `user@host.com` or an SSH config alias).
# - `[LOCAL_PORT]`
#     Local port to forward to (default: 8081).
#
# Returns
# -------
# - `status`
#     0 on success, 1 on failure.
code-server-tunnel() {
    # Handle --list flag.
    if [[ "${1:-}" == "--list" ]]; then
        echo "Active code-server SSH tunnels:"
        ps aux | grep "ssh -fNL.*localhost:${_CS_TUNNEL_REMOTE_PORT}" | grep -v grep || echo "  (none)"
        return 0
    fi

    # Handle --kill flag.
    if [[ "${1:-}" == "--kill" ]]; then
        local host="${2:-}"
        if [[ -z "${host}" ]]; then
            echo "Usage: code-server-tunnel --kill HOST" >&2
            return 1
        fi
        local pids
        pids=$(pgrep -f "ssh -fNL.*localhost:${_CS_TUNNEL_REMOTE_PORT} ${host}" 2>/dev/null)
        if [[ -z "${pids}" ]]; then
            echo "No active tunnel found for ${host}."
            return 0
        fi
        echo "Killing tunnel(s) for ${host}: PID ${pids}"
        echo "${pids}" | xargs kill 2>/dev/null
        return 0
    fi

    # Parse positional arguments.
    local host="${1:-}"
    local local_port="${2:-${_CS_TUNNEL_LOCAL_PORT_DEFAULT}}"

    if [[ -z "${host}" ]]; then
        echo "Usage: code-server-tunnel HOST [LOCAL_PORT]" >&2
        echo "" >&2
        echo "  HOST        SSH host (full hostname or SSH config alias)" >&2
        echo "  LOCAL_PORT  Local port to bind (default: ${_CS_TUNNEL_LOCAL_PORT_DEFAULT})" >&2
        echo "" >&2
        echo "Examples:" >&2
        echo "  code-server-tunnel myhost.example.com        # localhost:8081 → remote:8080" >&2
        echo "  code-server-tunnel myhost.example.com 8082   # localhost:8082 → remote:8080" >&2
        echo "  code-server-tunnel --kill myhost.example.com # kill the tunnel" >&2
        echo "  code-server-tunnel --list                    # show active tunnels" >&2
        return 1
    fi

    # Check if tunnel already exists.
    local existing_pid
    existing_pid=$(pgrep -f "ssh -fNL ${local_port}:localhost:${_CS_TUNNEL_REMOTE_PORT} ${host}" 2>/dev/null | head -1)
    if [[ -n "${existing_pid}" ]]; then
        echo "Tunnel already active: localhost:${local_port} → ${host}:${_CS_TUNNEL_REMOTE_PORT} (PID ${existing_pid})"
        echo "Access code-server at: http://localhost:${local_port}"
        return 0
    fi

    # Check if local port is in use by something else.
    if lsof -i ":${local_port}" &>/dev/null; then
        echo "ERROR: Local port ${local_port} is already in use." >&2
        echo "Try a different port: code-server-tunnel ${host} $((local_port + 1))" >&2
        return 1
    fi

    # Create the tunnel.
    echo "Creating SSH tunnel: localhost:${local_port} → ${host}:${_CS_TUNNEL_REMOTE_PORT} ..."

    # Tag every line ssh (and its ProxyCommand, e.g. the WSSH proxy) writes
    # with the tunnel it belongs to. `ssh -f` forks into the background after
    # authenticating, and the forked child inherits these redirections — so if
    # the connection later drops (e.g. the laptop sleeps), the "session ended
    # unexpectedly" notice is still prefixed with this host and port instead of
    # appearing with no context and leaving you guessing which tunnel died.
    local tag="localhost:${local_port} → ${host}:${_CS_TUNNEL_REMOTE_PORT}"
    ssh -fNL "${local_port}:localhost:${_CS_TUNNEL_REMOTE_PORT}" "${host}" \
        > >(sed "s|^|[acst ${tag}] |") \
        2> >(sed "s|^|[acst ${tag}] |" >&2)
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "Tunnel established. Access code-server at: http://localhost:${local_port}"
    else
        echo "ERROR: Failed to create SSH tunnel for ${tag} (exit code: ${rc})." >&2
        return 1
    fi
}
