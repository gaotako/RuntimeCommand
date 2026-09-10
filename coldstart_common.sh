#!/bin/bash
# Shared code-server coldstart logic for all platforms.
#
# Provides reusable functions for bootstrapping code-server settings and
# extensions. Platform-specific coldstart scripts (`linux/code_server/coldstart.sh`,
# `macos/code_server/coldstart.sh`, `sagemaker/code_server/coldstart.sh`)
# source this file after defining platform hooks, then call `_coldstart_run`.
#
# Prerequisites
# -------------
# The caller must define the following before sourcing this file:
# - `_sed_i`
#     Portable `sed -i` wrapper matching the host OS (BSD or GNU).
# - `_readlink_f`
#     Portable `readlink -f` replacement (macOS BSD readlink lacks `-f`).
# - `_coldstart_install_extension_cmd EXTENSION_NAME`
#     Platform-specific `${CONTAINER_RUNTIME} run ... --install-extension`
#     command. Called only when the extension is not already installed.
#
# The caller must have already sourced `config.sh` (provides
# `XDG_DATA_HOME`, `IMAGE_NAME`, `IMAGE_TAG`, `DOCKER_HOME`, `DOCKER_SHELL`,
# `CONTAINER_RUNTIME`, `WORKSPACE`).
#
# The caller must have set up logging via `shutils/log.sh` (provides
# `log_log`, `LOG_INDENT`).
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)

# Prevent redundant sourcing.
[[ ${_COLDSTART_COMMON_SH_LOADED:-0} -eq 1 ]] && return
_COLDSTART_COMMON_SH_LOADED=1

# Symlink User settings from the shared repo directory to the code-server
# data directory.
#
# Args
# ----
# - `quiet`
#     When set to `1`, suppresses step-by-step log output.
# - `shared_cs_root`
#     Path to the shared `code_server/` directory in the repo.
# - `settings_root`
#     Path to the code-server data directory (e.g., `XDG_DATA_HOME/code-server`).
#
# Returns
# -------
# (No-Returns)
_coldstart_link_user_settings() {
    local quiet="${1}" shared_cs_root="${2}" settings_root="${3}"
    local here="${shared_cs_root}/User/settings.json"
    local there="${settings_root}/User/settings.json"

    log_log "${quiet}" "[1/4] Linking User settings ..."
    if [[ ! -L "${there}" || "$(_readlink_f "${there}")" != "$(_readlink_f "${here}")" ]]; then
        if [[ -f "${there}" ]]; then
            mv "${there}" "${there}.bak"
            rm -f "${here}.bak"
            ln -s "${there}.bak" "${here}.bak"
        else
            rm -f "${there}"
        fi
        mkdir -p "$(dirname "${there}")"
        ln -s "${here}" "${there}"
    fi
}

# Template Machine settings with the resolved Python path and Docker shell,
# then symlink to the code-server data directory.
#
# Args
# ----
# - `quiet`
#     When set to `1`, suppresses step-by-step log output.
# - `shared_cs_root`
#     Path to the shared `code_server/` directory in the repo.
# - `settings_root`
#     Path to the code-server data directory.
#
# Returns
# -------
# (No-Returns)
_coldstart_template_machine_settings() {
    local quiet="${1}" shared_cs_root="${2}" settings_root="${3}"

    log_log "${quiet}" "[2/4] Templating Machine settings ..."
    local system_python_path="python"
    log_log "${quiet}" "Python path: ${system_python_path}"
    log_log "${quiet}" "Docker shell: ${DOCKER_SHELL}"

    rm -f "${shared_cs_root}/Machine/settings.json"
    cp "${shared_cs_root}/Machine/settings-template.json" "${shared_cs_root}/Machine/settings.json"

    local python_sed docker_shell_sed
    python_sed="$(echo "${system_python_path}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
    docker_shell_sed="$(echo "${DOCKER_SHELL}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
    _sed_i -e "s/\${PYTHON_PATH}/${python_sed}/g" \
        -e "s/\${DOCKER_SHELL}/${docker_shell_sed}/g" \
        "${shared_cs_root}/Machine/settings.json"

    local here="${shared_cs_root}/Machine/settings.json"
    local there="${settings_root}/Machine/settings.json"
    if [[ ! -L "${there}" || "$(_readlink_f "${there}")" != "$(_readlink_f "${here}")" ]]; then
        if [[ -f "${there}" ]]; then
            mv "${there}" "${there}.bak"
            rm -f "${here}.bak"
            ln -s "${there}.bak" "${here}.bak"
        else
            rm -f "${there}"
        fi
        mkdir -p "$(dirname "${there}")"
        ln -s "${here}" "${there}"
    fi
}

# Install the sync-settings extension if not already present.
#
# Delegates to the platform-defined `_coldstart_install_extension_cmd`
# function for the actual `docker run` invocation.
#
# Args
# ----
# - `quiet`
#     When set to `1`, suppresses step-by-step log output.
# - `shared_cs_root`
#     Path to the shared `code_server/` directory in the repo.
# - `settings_root`
#     Path to the code-server data directory.
#
# Returns
# -------
# (No-Returns)
_coldstart_install_sync_settings() {
    local quiet="${1}" shared_cs_root="${2}" settings_root="${3}"
    local sync_settings_root="${settings_root}/User/globalStorage/zokugun.sync-settings"

    log_log "${quiet}" "[3/4] Installing sync-settings extension ..."
    if [[ ! -d "${sync_settings_root}" ]]; then
        _coldstart_install_extension_cmd "zokugun.sync-settings"
    fi
}

# Template and symlink the sync-settings configuration with the resolved
# project root path.
#
# Args
# ----
# - `quiet`
#     When set to `1`, suppresses step-by-step log output.
# - `shared_cs_root`
#     Path to the shared `code_server/` directory in the repo.
# - `settings_root`
#     Path to the code-server data directory.
# - `project_root`
#     Absolute path to the RuntimeCommand project root.
#
# Returns
# -------
# (No-Returns)
_coldstart_configure_sync_settings() {
    local quiet="${1}" shared_cs_root="${2}" settings_root="${3}" project_root="${4}"
    local source_root="${shared_cs_root}/User/globalStorage/zokugun.sync-settings"
    local target_root="${settings_root}/User/globalStorage/zokugun.sync-settings"

    log_log "${quiet}" "[4/4] Configuring sync-settings ..."
    rm -f "${source_root}/settings.yml"
    cp "${source_root}/settings-template.yml" "${source_root}/settings.yml"

    local project_root_sed
    project_root_sed="$(echo "${project_root}" | sed -E "s/([\\/\\.&])/\\\\\1/g")"
    _sed_i -e "s/\${PROJECT_ROOT}/${project_root_sed}/g" "${source_root}/settings.yml"

    local here="${source_root}/settings.yml"
    local there="${target_root}/settings.yml"
    if [[ ! -L "${there}" || "$(_readlink_f "${there}")" != "$(_readlink_f "${here}")" ]]; then
        if [[ -f "${there}" ]]; then
            mv "${there}" "${there}.bak"
            rm -f "${here}.bak"
            ln -s "${there}.bak" "${here}.bak"
        else
            rm -f "${there}"
        fi
        mkdir -p "$(dirname "${there}")"
        ln -s "${here}" "${there}"
    fi
}

# Run the full coldstart sequence.
#
# Calls all four coldstart steps in order. The caller must have defined the
# platform hooks (`_sed_i`, `_readlink_f`, `_coldstart_install_extension_cmd`)
# and sourced `config.sh` before calling this function.
#
# Args
# ----
# - `quiet`
#     When set to `1`, suppresses step-by-step log output.
# - `project_root`
#     Absolute path to the RuntimeCommand project root.
#
# Returns
# -------
# (No-Returns)
_coldstart_run() {
    local quiet="${1}" project_root="${2}"
    local shared_cs_root="${project_root}/code_server"
    local settings_root="${XDG_DATA_HOME}/code-server"

    _coldstart_link_user_settings "${quiet}" "${shared_cs_root}" "${settings_root}"
    _coldstart_template_machine_settings "${quiet}" "${shared_cs_root}" "${settings_root}"
    _coldstart_install_sync_settings "${quiet}" "${shared_cs_root}" "${settings_root}"
    _coldstart_configure_sync_settings "${quiet}" "${shared_cs_root}" "${settings_root}" "${project_root}"

    log_log "${quiet}" "Coldstart complete. Run \`Sync Settings: Download (repository -> user)\` in code-server."
}
