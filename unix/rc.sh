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

export CISH=$(ps -o comm -p $$ | tail -1 | awk "{print \$NF}")

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
    error "UNIX system must have HOME and WORKSPACE claimed before execute runtime command."
    return 1
fi

export XDG_ROOT=${WORKSPACE}/CrossDesktopGroup
export XDG_CONFIG_HOME=${XDG_ROOT}/config
export XDG_CACHE_HOME=${XDG_ROOT}/cache
export XDG_DATA_HOME=${XDG_ROOT}/local/share
export XDG_STATE_HOME=${XDG_ROOT}/local/state

[[ -d ${XDG_ROOT} ]] || mkdir -p ${XDG_ROOT}
[[ -d ${XDG_CONFIG_HOME} ]] || mkdir -p ${XDG_CONFIG_HOME}
[[ -d ${XDG_CACHE_HOME} ]] || mkdir -p ${XDG_CACHE_HOME}
[[ -d ${XDG_DATA_HOME} ]] || mkdir -p ${XDG_DATA_HOME}
[[ -d ${XDG_STATE_HOME} ]] || mkdir -p ${XDG_STATE_HOME}

export APP_ROOT=${WORKSPACE}/Application
export APP_DATA_HOME=${APP_ROOT}/data
export APP_BIN_HOME=${APP_ROOT}/bin

[[ -d ${APP_ROOT} ]] || mkdir -p ${APP_ROOT}
[[ -d ${APP_DATA_HOME} ]] || mkdir -p ${APP_DATA_HOME}
[[ -d ${APP_BIN_HOME} ]] || mkdir -p ${APP_BIN_HOME}

export SSH_HOME=${WORKSPACE}/RuntimeCommand/ssh

mkdir -p ${SSH_HOME}
if [[ ! -L ${HOME}/.ssh || $(readlink -f ${HOME}/.ssh) != ${SSH_HOME} ]]; then
    rm -rf ${HOME}/.ssh
    ln -s ${SSH_HOME} ${HOME}/.ssh
fi

ssh-kgq-ecdsa() {
    ssh-keygen -t ecdsa -q -f "${SSH_HOME}/id_ecdsa" -N ""
}

ssh-kgq-rsa() {
    ssh-keygen -t rsa -b 2048 -m PEM -q -f "${SSH_HOME}/id_rsa" -N ""
}

for encrypt in ecdsa rsa; do
    if [[ ! -f ${SSH_HOME}/id_${encrypt} ]]; then
        ssh-kgq-${encrypt}
        if [[ ${?} -eq 0 ]]; then
            break
        fi
    else
        break
    fi
done

export RC_ROOT=${WORKSPACE}/RuntimeCommandReadOnly/src/RuntimeCommand
if [[ -d ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand ]]; then
    export RC_ROOT=${WORKSPACE}/RuntimeCommand/src/RuntimeCommand
elif [[ ! -d ${RC_ROOT} ]]; then
    mkdir -p $(dirname ${RC_ROOT})
    git clone https://github.com/gaotako/RuntimeCommand.git ${RC_ROOT}
fi

for rcfile in bashrc zshrc; do
    if [[ -f ${HOME}/.${rcfile} ]]; then
        if [[ ! -L ${WORKSPACE}/RuntimeCommand/${rcfile}.sh || $(readlink -f ${WORKSPACE}/RuntimeCommand/${rcfile}.sh) != ${HOME}/.${rcfile} ]]; then
            rm -rf ${WORKSPACE}/RuntimeCommand/${rcfile}.sh
            ln -s ${HOME}/.${rcfile} ${WORKSPACE}/RuntimeCommand/${rcfile}.sh
        fi
    fi
done

if [[ -n $(which tmux) && -n ${TMUX} ]]; then
    WISHID=$(tmux display-message -p "#S/#I" 2>/dev/null)
else
    WISHID=""
fi

case ${CISH} in
*bash*)
    shopt -s promptvars
    echo -e "Detect Current Interactive Shell (CISH): \"${PSC_ASCII_BRIGHT_RED}${CISH}${PSC_ASCII_RESET}\" (bash)."
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}\#${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}\u${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}\h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}[${PSC_ASCII_BRIGHT_MAGENTA}${WISHID}${PSC_ASCII_RESET}]"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}\w${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}\W${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*zsh*)
    echo -e "Detect Current Interactive Shell (CISH): \"${PSC_ASCII_BRIGHT_RED}${CISH}${PSC_ASCII_RESET}\" (zsh)."
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}%h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}%n${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}%m${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}[${PSC_ASCII_BRIGHT_MAGENTA}${WISHID}${PSC_ASCII_RESET}]"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}%~${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}%c${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*sh*)
    shopt -s promptvars
    echo -e "Detect Current Interactive Shell (CISH): \"${PSC_ASCII_BRIGHT_RED}${CISH}${PSC_ASCII_RESET}\" (~bash)."
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}\#${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}\u${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}\h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}[${PSC_ASCII_BRIGHT_MAGENTA}${WISHID}${PSC_ASCII_RESET}]"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}\w${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}\W${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*)
    echo -e "Detect UNKNOWN Current Interactive Shell (CISH): \"${CISH}\", thus adopt UNFORMATTED header."
    CLI_HEADER="#\# \u@\h[${WISHID}]:\w|\W"
    export PS1="${PSC_ASCII_NEWLINE}${CLI_HEADER}${PSC_ASCII_NEWLINE}$ "
    ;;
esac

if [[ -z $(which mise) ]]; then
    case ${CISH} in
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
        echo -e "Detect UNKNOWN Current Interactive Shell (CISH): \"${CISH}\", thus MISE is not activated."
        return 1
        ;;
    esac
fi

mise settings experimental=true 2>/dev/null
if [[ ${?} -gt 0 ]]; then
    warning "mise of installed version does not have experimental option."
fi

mise use -g python@3.12 python@3.11 python@3.10 python@3.9
