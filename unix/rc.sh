CISH=$(ps -p $$ | tail -1 | awk "{print \$NF}")

if [[ -z ${HOME} || -z ${WORKSPACE} ]]; then
    echo -e "UNIX system must have HOME and WORKSPACE claimed before execute runtime command."
    exit 1
fi

if [[ -n $(which tmux) && -n ${TMUX} ]]; then
    WISHID=$(tmux display-message -p "#S/#I" 2>/dev/null)
else
    WISHID=""
fi

PSC_ASCII_RESET=$'\e[0m'
PSC_ASCII_RED=$'\e[31m'
PSC_ASCII_GREEN=$'\e[32m'
PSC_ASCII_YELLOW=$'\e[33m'
PSC_ASCII_BLUE=$'\e[34m'
PSC_ASCII_CYAN=$'\e[35m'
PSC_ASCII_MAGENTA=$'\e[36m'
PSC_ASCII_BRIGHT_RED=$'\e[91m'
PSC_ASCII_BRIGHT_GREEN=$'\e[92m'
PSC_ASCII_BRIGHT_YELLOW=$'\e[93m'
PSC_ASCII_BRIGHT_BLUE=$'\e[94m'
PSC_ASCII_BRIGHT_CYAN=$'\e[95m'
PSC_ASCII_BRIGHT_MAGENTA=$'\e[96m'
PSC_ASCII_NEWLINE=$'\n'

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
    CLI_HEADER="${CLI_HEADER}#${PSC_ASCII_CYAN}\#${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER} ${PSC_ASCII_BRIGHT_GREEN}\u${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}@${PSC_ASCII_BRIGHT_BLUE}\h${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}[${PSC_ASCII_BRIGHT_MAGENTA}${WISHID}${PSC_ASCII_RESET}]"
    CLI_HEADER="${CLI_HEADER}:${PSC_ASCII_YELLOW}\w${PSC_ASCII_RESET}"
    CLI_HEADER="${CLI_HEADER}|${PSC_ASCII_BRIGHT_YELLOW}\W${PSC_ASCII_RESET}"
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

export XDG_ROOT=${WORKSPACE}/CrossDesktopGroup
export XDG_CONFIG_HOME=${XDG_ROOT}/config
export XDG_CACHE_HOME=${XDG_ROOT}/cache
export XDG_DATA_HOME=${XDG_ROOT}/local/share
export XDG_STATE_HOME=${XDG_ROOT}/local/state

export APP_ROOT=${WORKSPACE}/Application
export APP_DATA_HOME=${APP_ROOT}/data
export APP_BIN_HOME=${APP_ROOT}/bin

export SSH_HOME=${XDG_ROOT}/ssh

alias ssh-kgq="ssh-keygen -t rsa -q -f \"${SSH_HOME}/id_rsa\" -N \"\""

mkdir -p ${SSH_HOME}
if [[ ! -f ${SSH_HOME}/id_rsa ]]; then
    ssh-kgq
fi

export RC_ROOT=${WORKSPACE}/RuntimeCommandReadOnly
if [[ -d ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand ]]; then
    export RC_ROOT=${WORKSPACE}/RuntimeCommand/src/RuntimeCommand
fi

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
        exit 1
        ;;
    esac

fi

mise settings experimental=true 2> /dev/null
if [[ $? -gt 0 ]]; then
    echo -e "mise of installed version does not have experimental option."
fi
mise use -g python@3.11 python@3.10 python@3.12 python@3.9