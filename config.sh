#!/bin/bash
# Shared configuration and defaults for docker scripts.
#
# Defines defaults for all configurable variables and applies them. Each
# variable follows the pattern `VAR_DEFAULT=...; VAR="${VAR:-${VAR_DEFAULT}}"`.
# Scripts source this file to avoid repeating the same definitions.
#
# Args
# ----
# (No-Args)
#
# Returns
# -------
# (No-Returns)

# Prevent redundant sourcing.
[[ ${_DOCKER_CONFIG_SH_LOADED:-0} -eq 1 ]] && return
_DOCKER_CONFIG_SH_LOADED=1

# Platform detection.
# Auto-detects the platform from the environment when RC_PLATFORM is unset.
# - `sagemaker`: SageMaker Notebook Instance (ec2-user, Jupyter present).
# - `linux`:     Generic Linux / AL2 Cloud Desktop (default for Linux).
# - `macos`:     macOS (Darwin kernel).
if [[ -z "${RC_PLATFORM:-}" ]]; then
    case "$(uname -s)" in
    Darwin*)
        RC_PLATFORM="macos"
        ;;
    Linux*)
        if [[ "$(whoami)" == "ec2-user" && -d "${HOME}/SageMaker" ]]; then
            RC_PLATFORM="sagemaker"
        else
            RC_PLATFORM="linux"
        fi
        ;;
    *)
        RC_PLATFORM="linux"
        ;;
    esac
fi

# Platform-conditional path defaults.
HOME_DEFAULT="${HOME:-/home/$(whoami)}"
case "${RC_PLATFORM}" in
sagemaker)
    WORKSPACE_DEFAULT="${HOME:-${HOME_DEFAULT}}/SageMaker"
    ;;
*)
    WORKSPACE_DEFAULT="${HOME:-${HOME_DEFAULT}}/Workspace"
    ;;
esac
APP_ROOT_DEFAULT="${WORKSPACE:-${WORKSPACE_DEFAULT}}/Application"
APP_DATA_HOME_DEFAULT="${APP_ROOT:-${APP_ROOT_DEFAULT}}/data"
CODE_SERVER_APPLICATION_DEFAULT="${APP_DATA_HOME:-${APP_DATA_HOME_DEFAULT}}/cs"
CODE_SERVER_DEFAULT="${CODE_SERVER_APPLICATION:-${CODE_SERVER_APPLICATION_DEFAULT}}/bin/code-server"

# Apply path defaults.
HOME="${HOME:-${HOME_DEFAULT}}"
WORKSPACE="${WORKSPACE:-${WORKSPACE_DEFAULT}}"
APP_ROOT="${APP_ROOT:-${APP_ROOT_DEFAULT}}"
APP_DATA_HOME="${APP_DATA_HOME:-${APP_DATA_HOME_DEFAULT}}"
APP_BIN_HOME="${APP_ROOT}/bin"
CODE_SERVER_APPLICATION="${CODE_SERVER_APPLICATION:-${CODE_SERVER_APPLICATION_DEFAULT}}"
CODE_SERVER="${CODE_SERVER:-${CODE_SERVER_DEFAULT}}"

# code-server version defaults.
CODE_SERVER_VERSION_DEFAULT="latest"
CODE_SERVER_VERSION="${CODE_SERVER_VERSION:-${CODE_SERVER_VERSION_DEFAULT}}"

# Docker image coordinates.
IMAGE_NAME="code-server-runtime"
IMAGE_TAG="latest"

# Docker image persistence defaults.
case "${RC_PLATFORM}" in
sagemaker)
    DOCKER_IMAGE_DIR_DEFAULT="${HOME}/SageMaker/CodeServerDockerImage"
    ;;
*)
    DOCKER_IMAGE_DIR_DEFAULT="${WORKSPACE}/CodeServerDockerImage"
    ;;
esac
DOCKER_IMAGE_DIR="${DOCKER_IMAGE_DIR:-${DOCKER_IMAGE_DIR_DEFAULT}}"

# Docker container home defaults.
case "${RC_PLATFORM}" in
sagemaker)
    DOCKER_HOME_DEFAULT="/home/ec2-user/SageMaker/CodeServerDockerHome"
    ;;
*)
    DOCKER_HOME_DEFAULT="${WORKSPACE}/CodeServerDockerHome"
    ;;
esac
DOCKER_HOME="${DOCKER_HOME:-${DOCKER_HOME_DEFAULT}}"

# Docker container shell defaults.
DOCKER_SHELL_DEFAULT="/bin/zsh"
DOCKER_SHELL="${DOCKER_SHELL:-${DOCKER_SHELL_DEFAULT}}"

# XDG base directories under the Docker-specific home.
XDG_ROOT="${DOCKER_HOME}/CrossDesktopGroup"
XDG_DATA_HOME="${XDG_ROOT}/local/share"
XDG_CONFIG_HOME="${XDG_ROOT}/config"
XDG_CACHE_HOME="${XDG_ROOT}/cache"
XDG_STATE_HOME="${XDG_ROOT}/local/state"

# Mise runtime manager defaults.
MISE_INSTALL_PATH_DEFAULT="/usr/local/bin/mise"
MISE_INSTALL_PATH="${MISE_INSTALL_PATH:-${MISE_INSTALL_PATH_DEFAULT}}"
MISE_NODE_VERSION_DEFAULT="22"
MISE_NODE_VERSION="${MISE_NODE_VERSION:-${MISE_NODE_VERSION_DEFAULT}}"
MISE_PYTHON_VERSIONS_DEFAULT="python@3.13 python@3.12 python@3.11 python@3.10"
MISE_PYTHON_VERSIONS="${MISE_PYTHON_VERSIONS:-${MISE_PYTHON_VERSIONS_DEFAULT}}"
MISE_JAVA_VERSION_DEFAULT="21"
MISE_JAVA_VERSION="${MISE_JAVA_VERSION:-${MISE_JAVA_VERSION_DEFAULT}}"

# Docker container name defaults.
CONTAINER_NAME_DEFAULT="code-server-runtime"
CONTAINER_NAME="${CONTAINER_NAME:-${CONTAINER_NAME_DEFAULT}}"

# Jupyter configuration defaults (SageMaker only).
JUPYTER_CONFIG_DEFAULT="${HOME}/.jupyter/jupyter_notebook_config.py"
JUPYTER_CONFIG="${JUPYTER_CONFIG:-${JUPYTER_CONFIG_DEFAULT}}"
