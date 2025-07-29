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

case ${cish} in
*bash*)
    shdir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
    ;;
*zsh*)
    shdir=${0:a:h}
    ;;
*sh*)
    shdir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
    ;;
*)
    echo -e "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus this script directory can not be detected."
    return 1 2>/dev/null || exit 1
    ;;
esac

args=()
coldstart=0
mise=1
while [[ $# -gt 0 ]]; do
    case ${1} in
    -C|--coldstart)
        coldstart=1
        shift 1
        ;;
    -M|--no-mise)
        mise=0
        shift 1
        ;;
    *)
        args+=("${1}")
        shift 1
        ;;
    esac
done
if [[ ${#args[@]} -gt 0 ]]; then
    set -- "${args[@]}"
fi

if [[ -z ${HOME} || -z ${WORKSPACE} ]]; then
    error "UNIX system must have HOME and WORKSPACE claimed before execute runtime command."
    return 1 2>/dev/null || exit 1
fi

export XDG_ROOT=${WORKSPACE}/CrossDesktopGroup
export XDG_CONFIG_HOME=${XDG_ROOT}/config
export XDG_CACHE_HOME=${XDG_ROOT}/cache
export XDG_DATA_HOME=${XDG_ROOT}/local/share
export XDG_STATE_HOME=${XDG_ROOT}/local/state

if [[ ${coldstart} -eq 0 ]]; then
    [[ -d ${XDG_ROOT} ]] || ( error "Runtime command dependent directory \"${XDG_ROOT}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
    [[ -d ${XDG_CONFIG_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_CONFIG_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
    [[ -d ${XDG_CACHE_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_CACHE_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
    [[ -d ${XDG_DATA_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_DATA_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
    [[ -d ${XDG_STATE_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_STATE_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
else
    mkdir -p ${XDG_ROOT}
    mkdir -p ${XDG_CONFIG_HOME}
    mkdir -p ${XDG_CACHE_HOME}
    mkdir -p ${XDG_DATA_HOME}
    mkdir -p ${XDG_STATE_HOME}
fi

export APP_ROOT=${WORKSPACE}/Application
export APP_DATA_HOME=${APP_ROOT}/data
export APP_BIN_HOME=${APP_ROOT}/bin

if [[ ${coldstart} -eq 0 ]]; then
    [[ -d ${APP_ROOT} ]] || ( error "Runtime command dependent directory \"${APP_ROOT}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
    [[ -d ${APP_DATA_HOME} ]] || ( error "Runtime command dependent directory \"${APP_DATA_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
    [[ -d ${APP_BIN_HOME} ]] || ( error "Runtime command dependent directory \"${APP_BIN_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
else
    mkdir -p ${APP_ROOT}
    mkdir -p ${APP_DATA_HOME}
    mkdir -p ${APP_BIN_HOME}
fi

if [[ -z ${RC_TOP} ]]; then
    export RC_TOP=${WORKSPACE}/RuntimeCommandReadOnly
    if [[ -d ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand ]]; then
        export RC_TOP=${WORKSPACE}/RuntimeCommand
    fi
fi
export RC_ROOT=${RC_TOP}/src/RuntimeCommand
if [[ ! -d ${RC_ROOT} ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "Runtime command root directory \"${RC_ROOT}\" is not ready."
        return 1 2>/dev/null || exit 1
    else
        mkdir -p $(dirname ${RC_ROOT})
        git clone git@github.com:gaotako/RuntimeCommand.git ${RC_ROOT}
        if [[ $? -ne 0 ]]; then
            rm -rf $(dirname ${RC_ROOT})
            warning "Fail to clone by ssh, fall back to read-only clone by tcp."
            export RC_TOP=${WORKSPACE}/RuntimeCommandReadOnly
            export RC_ROOT=${RC_TOP}/src/RuntimeCommand
            mkdir -p $(dirname ${RC_ROOT})
            git clone https://github.com/gaotako/RuntimeCommand.git ${RC_ROOT}
        fi
    fi
fi

export SSH_HOME=${RC_TOP}/ssh
export AWS_HOME=${RC_TOP}/aws

if [[ ! -L ${HOME}/.ssh || $(readlink -f ${HOME}/.ssh) != $(readlink -f ${SSH_HOME}) ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "SSH directory \"${SSH_HOME}\" is not properly relinked."
        return 1 2>/dev/null || exit 1
    else
        rm -rf ${SSH_HOME}
        mkdir -p ${SSH_HOME}
        if [[ -n $(ls ${HOME}/.ssh 2>/dev/null) ]]; then
            cp ${HOME}/.ssh/* ${SSH_HOME}
        fi
        rm -rf ${HOME}/.ssh
        ln -s ${SSH_HOME} ${HOME}/.ssh
    fi
fi
mkdir -p ${SSH_HOME}

if [[ ! -L ${HOME}/.aws || $(readlink -f ${HOME}/.aws) != $(readlink -f ${AWS_HOME}) ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "AWS directory \"${AWS_HOME}\" is not properly relinked."
        return 1 2>/dev/null || exit 1
    else
        rm -rf ${AWS_HOME}
        mkdir -p ${AWS_HOME}
        if [[ -n $(ls ${HOME}/.aws 2>/dev/null) ]]; then
            cp ${HOME}/.aws/* ${AWS_HOME}
        fi
        rm -rf ${HOME}/.aws
        ln -s ${AWS_HOME} ${HOME}/.aws
    fi
fi
mkdir -p ${AWS_HOME}

ssh_kgq_ecdsa() {
    ssh-keygen -t ecdsa -q -f "${SSH_HOME}/id_ecdsa" -N ""
}

ssh_kgq_rsa() {
    ssh-keygen -t rsa -b 2048 -m PEM -q -f "${SSH_HOME}/id_rsa" -N ""
}

for encrypt in ecdsa rsa; do
    if [[ ! -f ${SSH_HOME}/id_${encrypt} ]]; then
        ssh_kgq_${encrypt}
        if [[ $? -eq 0 ]]; then
            break
        fi
    else
        break
    fi
done

case ${cish} in
*bash*)
    rcfile=bashrc
    ;;
*zsh*)
    rcfile=zshrc
    ;;
*sh*)
    rcfile=bashrc
    ;;
*)
    error "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus rc file is not defined."
    return 1 2>/dev/null || exit 1
    ;;
esac
if [[ ! -f ${HOME}/.${rcfile} ]]; then
    error "Runtime command script entrance \"${HOME}/.${rcfile}\" is not ready."
    return 1 2>/dev/null || exit 1
fi
if [[ ! -L ${RC_TOP}/${rcfile}.sh || $(readlink -f ${RC_TOP}/${rcfile}.sh) != $(readlink -f ${HOME}/.${rcfile}) ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "Runtime command script \"${RC_TOP}/${rcfile}.sh\" is not properly relinked."
        return 1 2>/dev/null || exit 1
    else
        rm -rf ${RC_TOP}/${rcfile}.sh
        ln -s ${HOME}/.${rcfile} ${RC_TOP}/${rcfile}.sh
    fi
fi

if [[ -n $(which tmux 2>/dev/null) && -n ${TMUX} ]]; then
    wishid=$(tmux display-message -p "#S/#I" 2>/dev/null)
else
    wishid=""
fi

case ${cish} in
*bash*)
    shopt -s promptvars
    echo -e "Detect Current Interactive Shell (CISH): \"${PSC_ASCII_BRIGHT_BLUE}${cish}${PSC_ASCII_RESET}\" (bash)."
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}\#${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}\u${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}\h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}[${PSC_ASCII_BRIGHT_MAGENTA}${wishid}${PSC_ASCII_RESET}]"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}\w${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}\W${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*zsh*)
    echo -e "Detect Current Interactive Shell (CISH): \"${PSC_ASCII_BRIGHT_BLUE}${cish}${PSC_ASCII_RESET}\" (zsh)."
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}%h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}%n${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}%m${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}[${PSC_ASCII_BRIGHT_MAGENTA}${wishid}${PSC_ASCII_RESET}]"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}%~${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}%c${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*sh*)
    shopt -s promptvars
    echo -e "Detect Current Interactive Shell (CISH): \"${PSC_ASCII_BRIGHT_BLUE}${cish}${PSC_ASCII_RESET}\" (~bash)."
    CLI_HEADER=
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}\#${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}\u${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}\h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}[${PSC_ASCII_BRIGHT_MAGENTA}${wishid}${PSC_ASCII_RESET}]"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}\w${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}\W${PSC_ASCII_RESET}"
    export PS1="${PSC_ASCII_NEWLINE}${PSC_ASCII_RESET}${CLI_HEADER}${PSC_ASCII_RESET}${PSC_ASCII_NEWLINE}$ "
    ;;
*)
    echo -e "Detect UNKNOWN Current Interactive Shell (CISH): \"${cish}\", thus adopt UNFORMATTED header."
    CLI_HEADER="#\# \u@\h[${wishid}]:\w|\W"
    export PS1="${PSC_ASCII_NEWLINE}${CLI_HEADER}${PSC_ASCII_NEWLINE}$ "
    ;;
esac

if [[ -z ${RC_COMMAND_BOOT} ]]; then
    export RC_COMMAND_BOOT="source ${RC_ROOT}/unix/rc.sh"
fi
command="${RC_COMMAND_BOOT}"
if [[ -n ${command} && -z $(grep "^${command}$" ${RC_TOP}/${rcfile}.sh) ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "Runtime command script \"${command}\" is not properly included into system runtime command."
    else
        echo -e "Please ensure standalone \"${command}\" is in \"${RC_TOP}/${rcfile}.sh\"."
    fi
    return 1 2>/dev/null || exit 1
fi

if [[ -n $(which toolbox 2>/dev/null) ]]; then
    command="export PATH=\${HOME}/.toolbox/bin:\${PATH}"
    if [[ -n ${command} && -z $(grep "^${command}$" ${RC_TOP}/${rcfile}.sh) ]]; then
        if [[ ${coldstart} -eq 0 ]]; then
            error "Runtime command script (toolbox) \"${command}\" is not properly included into system runtime command."
        else
            echo -e "Please ensure standalone \"${command}\" is in \"${RC_TOP}/${rcfile}.sh\"."
        fi
        return 1 2>/dev/null || exit 1
    fi
fi

if [[ $(uname) == Darwin && -n $(which brew 2>/dev/null) ]]; then
    command="eval \"\$(/opt/homebrew/bin/brew shellenv)\""
    if [[ -n ${command} && -z $(grep "^${command}$" ${RC_TOP}/${rcfile}.sh) ]]; then
        if [[ ${coldstart} -eq 0 ]]; then
            error "Runtime command script (homebrew) \"${command}\" is not properly included into system runtime command."
        else
            echo -e "Please ensure standalone \"${command}\" is in \"${RC_TOP}/${rcfile}.sh\"."
        fi
        return 1 2>/dev/null || exit 1
    fi
fi

if [[ -n $(which rustup 2>/dev/null) ]]; then
    case ${cish} in
    *bash*)
        command="source \${HOME}/.cargo/env"
        ;;
    *zsh*)
        command=
        ;;
    *sh*)
        command="source \${HOME}/.cargo/env"
        ;;
    *)
        error "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus rustup is not defined."
        return 1 2>/dev/null || exit 1
        ;;
    esac
    if [[ -n ${command} && -z $(grep "^${command}$" ${RC_TOP}/${rcfile}.sh) ]]; then
        if [[ ${coldstart} -eq 0 ]]; then
            error "Runtime command script (rustup) \"${command}\" is not properly included into system runtime command."
        else
            echo -e "Please ensure standalone \"${command}\" is in \"${RC_TOP}/${rcfile}.sh\"."
        fi
        return 1 2>/dev/null || exit 1
    fi
fi

if [[ -n $(which brazil 2>/dev/null) ]]; then
    case ${cish} in
    *bash*)
        command="source ${HOME}/.brazil_completion/bash_completion"
        ;;
    *zsh*)
        command="source ${HOME}/.brazil_completion/zsh_completion"
        ;;
    *sh*)
        command="source ${HOME}/.brazil_completion/bash_completion"
        ;;
    *)
        error "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus brazil auto-complete is not defined."
        return 1 2>/dev/null || exit 1
        ;;
    esac
    if [[ -n ${command} && -z $(grep "^${command}$" ${RC_TOP}/${rcfile}.sh) ]]; then
        if [[ ${coldstart} -eq 0 ]]; then
            error "Runtime command script (brazil auto-complete) \"${command}\" is not properly included into system runtime command."
        else
            echo -e "Please ensure standalone \"${command}\" is in \"${RC_TOP}/${rcfile}.sh\"."
        fi
        return 1 2>/dev/null || exit 1
    fi
fi

if [[ ${mise} -ne 0 ]]; then
    source ${shdir}/mise.sh
else
    warning "Due to explicit argument, mise is skipped in runtime command."
fi