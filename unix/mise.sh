cish=$(ps -o comm -p $$ | tail -1 | cut -d " " -f 1)

export PSC_ASCII_RESET=$'\e[0m'
export PSC_ASCII_RED=$'\e[31m'
export PSC_ASCII_GREEN=$'\e[32m'
export PSC_ASCII_YELLOW=$'\e[33m'
export PSC_ASCII_BLUE=$'\e[34m'
export PSC_ASCII_CYAN=$'\e[35m'
export PSC_ASCII_MAGENTA=$'\e[36m'
export PSC_ASCII_BRIGHT_RED=$'\e[91m'
export PSC_ASCII_BRIGHT_GREEN=$'\e[92m'
export PSC_ASCII_BRIGHT_YELLOW=$'\e[93m'
export PSC_ASCII_BRIGHT_BLUE=$'\e[94m'
export PSC_ASCII_BRIGHT_CYAN=$'\e[95m'
export PSC_ASCII_BRIGHT_MAGENTA=$'\e[96m'
export PSC_ASCII_NEWLINE=$'\n'
echo -e "${PSC_ASCII_RESET}" >/dev/null

error() {
    echo -e "${PSC_ASCII_BRIGHT_RED}${1}${PSC_ASCII_RESET}"
}

warning() {
    echo -e "${PSC_ASCII_BRIGHT_YELLOW}${1}${PSC_ASCII_RESET}"
}

pass() {
    echo -e "${PSC_ASCII_BRIGHT_GREEN}${1}${PSC_ASCII_RESET}"
}

if [[ -z ${HOME} || -z ${WORKSPACE} ]]; then
    error "UNIX system must have HOME and WORKSPACE claimed before setup mise."
    return 1 2>/dev/null || exit 1
fi

[[ -d ${APP_BIN_HOME} ]] || ( error "Runtime command dependent directory \"${APP_BIN_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
[[ -d ${XDG_CONFIG_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_CONFIG_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
[[ -d ${XDG_DATA_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_DATA_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )

if [[ ! -f ${APP_BIN_HOME}/mise ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "mise is not properly installed."
        return 1
    else
        curl https://mise.run | MISE_INSTALL_PATH=${APP_BIN_HOME}/mise sh
    fi
fi
case ${cish} in
*bash*)
    eval "$(${APP_BIN_HOME}/mise activate bash)"
    ;;
*zsh*)
    eval "$(${APP_BIN_HOME}/mise activate zsh)"
    ;;
*sh*)
    eval "$(${APP_BIN_HOME}/mise activate bash)"
    ;;
*)
    echo -e "Detect UNKNOWN Current Interactive Shell (CISH): \"${cish}\", thus MISE is not activated."
    return 1
    ;;
esac

if [[ -f ${HOME}/.config/mise/config.toml ]]; then
    mv ${HOME}/.config/mise/config.toml ${XDG_CONFIG_HOME}/mise/config.toml
fi
for module_alt in node python; do
    if [[ -d ${HOME}/.local/share/mise/installs/${module_alt} ]]; then
        warning "There is \"${module_alt}\" managed by mise not configured by runtime command, and we will adopt it."
        rm -rf ${XDG_DATA_HOME}/mise/installs/${module_alt}
        mkdir -p ${XDG_DATA_HOME}/mise/installs/${module_alt}
        for version in `ls ${HOME}/.local/share/mise/installs/${module_alt}`; do
            ln -s ${HOME}/.local/share/mise/installs/${module_alt}/${version} ${XDG_DATA_HOME}/mise/installs/${module_alt}/${version}
        done
    fi
done
mise settings experimental=true
if [[ ${coldstart} -eq 0 ]]; then
    mise settings set not_found_auto_install 0
fi
if [[ -f /opt/ml/metadata/resource-metadata.json ]]; then
    node_version=16
else
    node_version=18.20
fi
mise use -g node@${node_version} python@3.12 python@3.11 python@3.10 python@3.9