#!/bin/bash
# Install (or remove) the daily 4am code-server container restart cron job.
#
# A nightly recreate keeps the long-lived container fresh: it picks up a newly
# built image and clears accumulated container state. This is shared across all
# Linux platforms (cloud desktop and SageMaker are both Linux with crontab), but
# the actual restart command is platform-specific because the two launch the
# container differently:
# - `linux`:     the container runs detached via `linux/wrapper.sh --detach`, so
#                the restart re-runs that (it does `docker rm -f` + recreate).
# - `sagemaker`: the container runs in the foreground with `--rm`, launched
#                on demand by `jupyter-server-proxy`. There is nothing to
#                re-launch headlessly, so the restart just removes the container
#                (`docker rm -f`); the proxy recreates it fresh on next access.
#
# This is a separate concern from surviving a host reboot: on `linux` the reboot
# is handled by `wrapper.sh`'s `--restart` policy; on `sagemaker` a stop/start
# wipes the image and is handled by the lifecycle `start.sh` hook. This script
# only owns the scheduled nightly restart.
#
# The entry is tagged with a marker comment so re-running this script replaces
# the existing entry rather than duplicating it, and `--remove` deletes it.
#
# Args
# ----
# - `--remove`
#     Remove the cron entry instead of installing it.
# - `--log-depth LOG_DEPTH`
#     Logging nesting depth, controls the `"=>"` prefix repetition
#     (default: `1`).
# - `--quiet`
#     When set, suppresses step-by-step log output.
#
# Returns
# -------
# (No-Returns)
#
# Notes
# -----
# The following environment variables can override defaults:
# - `CRON_RESTART_SCHEDULE`
#     Cron schedule for the restart (default: `"0 4 * * *"`, i.e. 4am daily).
# - `CRON_RESTART_LOG`
#     Path for the cron job's stdout/stderr (default:
#     `"${DOCKER_HOME}/cron-restart.log"`).
#
# Examples
# --------
# ```
# bash cron_setup.sh
# bash cron_setup.sh --remove
# CRON_RESTART_SCHEDULE="30 3 * * *" bash cron_setup.sh
# ```
set -euo pipefail

# Resolve directory paths (this script lives at the project root).
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

# Source shared libraries and defaults.
source "${PROJECT_ROOT}/shutils/argparse.sh"
source "${PROJECT_ROOT}/shutils/log.sh"

# Parse arguments (may set LOG_DEPTH, QUIET, REMOVE via --log-depth/--quiet/--remove).
argparse_parse "$@"
[[ ${#POSITIONAL_ARGS[@]} -gt 0 ]] && set -- "${POSITIONAL_ARGS[@]}"

# Load shared configuration (provides RC_PLATFORM, DOCKER_HOME, CONTAINER_NAME).
source "${PROJECT_ROOT}/config.sh"

# Build log indent from LOG_DEPTH.
log_make_indent "${LOG_DEPTH}"

# Resolve flags from argparse (--quiet sets QUIET=1, --remove sets REMOVE=1).
QUIET_DEFAULT=0
QUIET="${QUIET:-${QUIET_DEFAULT}}"
REMOVE_DEFAULT=0
REMOVE="${REMOVE:-${REMOVE_DEFAULT}}"

# This is a Linux-only concern; other platforms use their own mechanisms and
# may not have crontab. Skip cleanly so a shared installer can call it anywhere.
case "${RC_PLATFORM}" in
linux | sagemaker) ;;
*)
    log_log "${QUIET}" "Platform \`${RC_PLATFORM}\` has no cron restart; skipping."
    exit 0
    ;;
esac

# Cron entry defaults. The marker comment uniquely tags our entry so we can
# find and replace it without touching the user's other crontab lines.
CRON_RESTART_SCHEDULE_DEFAULT="0 4 * * *"
CRON_RESTART_SCHEDULE="${CRON_RESTART_SCHEDULE:-${CRON_RESTART_SCHEDULE_DEFAULT}}"
CRON_RESTART_LOG_DEFAULT="${DOCKER_HOME}/cron-restart.log"
CRON_RESTART_LOG="${CRON_RESTART_LOG:-${CRON_RESTART_LOG_DEFAULT}}"
CRON_MARKER="# RuntimeCommand code-server 4am restart (${CONTAINER_NAME})"

# Build the platform-specific restart action (see the header for why they differ).
case "${RC_PLATFORM}" in
linux)
    RESTART_ACTION="bash \"${PROJECT_ROOT}/linux/wrapper.sh\" --detach"
    ;;
sagemaker)
    RESTART_ACTION="docker rm -f \"${CONTAINER_NAME}\""
    ;;
esac

# The cron command runs in a login shell so PATH picks up docker (and mise),
# runs the platform restart action, and logs to CRON_RESTART_LOG for debugging.
CRON_COMMAND="${CRON_RESTART_SCHEDULE} /bin/bash -lc '${RESTART_ACTION}' >> \"${CRON_RESTART_LOG}\" 2>&1 ${CRON_MARKER}"

# Read the current crontab (empty if none installed yet), then strip any prior
# entry of ours (matched by the marker) so this operation is idempotent.
EXISTING_CRONTAB="$(crontab -l 2>/dev/null || true)"
FILTERED_CRONTAB="$(printf '%s\n' "${EXISTING_CRONTAB}" | grep -vF "${CRON_MARKER}" || true)"

if [[ "${REMOVE}" -eq 1 ]]; then
    # Remove: reinstall the crontab without our entry (empty crontab -> clear it).
    NONBLANK="$(printf '%s\n' "${FILTERED_CRONTAB}" | grep -v '^[[:space:]]*$' || true)"
    if [[ -n "${NONBLANK}" ]]; then
        printf '%s\n' "${NONBLANK}" | crontab -
    else
        crontab -r 2>/dev/null || true
    fi
    log_log "${QUIET}" "Removed 4am restart cron entry for \`${CONTAINER_NAME}\`."
    exit 0
fi

# Install: append our entry to the filtered crontab and load it back.
{
    printf '%s\n' "${FILTERED_CRONTAB}" | grep -v '^[[:space:]]*$' || true
    printf '%s\n' "${CRON_COMMAND}"
} | crontab -

log_log "${QUIET}" "Installed 4am restart cron entry for \`${CONTAINER_NAME}\` (${RC_PLATFORM}):"
log_log "${QUIET}" "  schedule: ${CRON_RESTART_SCHEDULE}"
log_log "${QUIET}" "  action:   ${RESTART_ACTION}"
log_log "${QUIET}" "  log:      ${CRON_RESTART_LOG}"
