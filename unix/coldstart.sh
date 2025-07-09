set -eux

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
    error "UNIX system must have HOME and WORKSPACE claimed before coldstart runtime command."
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

if [[ ! -f ${APP_BIN_HOME}/mise ]]; then
    curl https://mise.run | MISE_INSTALL_PATH=${APP_BIN_HOME}/mise sh
fi
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
if [[ -f ${HOME}/.config/mise/config.toml ]]; then
    mv ${HOME}/.config/mise/config.toml ${XDG_CONFIG_HOME}/mise/config.toml
fi
for module_alt in node python; do
    if [[ -d ${HOME}/.local/share/mise/installs/${module_alt} ]]; then
        rm -rf ${XDG_DATA_HOME}/mise/installs/${module_alt}
        mkdir -p ${XDG_DATA_HOME}/mise/installs/${module_alt}
        for version in `ls ${HOME}/.local/share/mise/installs/${module_alt}`; do
            ln -s ${HOME}/.local/share/mise/installs/${module_alt}/${version} ${XDG_DATA_HOME}/mise/installs/${module_alt}/${version}
        done
    fi
done
mise settings experimental=true
mise use -g node@18.20 python@3.12 python@3.11 python@3.10 python@3.9

case ${CISH} in
*bash*)
    rcfile=${HOME}/.bashrc
    ;;
*zsh*)
    rcfile=${HOME}/.zshrc
    ;;
*sh*)
    rcfile=${HOME}/.bashrc
    ;;
*)
    error "Detect UNKNOWN Current Interactive Shell (CISH): \"${CISH}\", thus rc file is not defined."
    return 1
    ;;
esac

if ! grep "^source ${RC_ROOT}/unix/rc.sh$" ${rcfile}; then
    warning "rc file is not included, and will be added automatically."
    echo "source ${RC_ROOT}/unix/rc.sh" >>${rcfile}
else
    pass "rc file has been included."
fi

if [[ -n $(which toolbox) ]]; then
    add_toolbox="export PATH=\${HOME}/.toolbox/bin:\${PATH}"
    add_toolbox_alt="export PATH=\$HOME/.toolbox/bin:\$PATH"
    if ! grep "^${add_toolbox}\$" ${rcfile}; then
        if grep "^${add_toolbox_alt}\$" ${rcfile}; then
            warning "toolbox path (alternative) has been included"
        else
            warning "toolbox path is not included"
        fi
    else
        pass "toolbox path has been included"
    fi
fi

if [[ -n $(which brew) ]]; then
    add_homebrew="eval \"\$(/opt/homebrew/bin/brew shellenv)\""
    if ! grep "^${add_homebrew}\$" ${rcfile}; then
        warning "homebrew path is not included"
    else
        pass "homebrew has been included"
    fi
fi

if [[ -n $(which rustup) ]]; then
    case ${CISH} in
    *bash*)
        add_rustup="source \${HOME}/.cargo/env"
        add_rustup_alt=". \"\$HOME/.cargo/env\""
        ;;
    *zsh*)
        add_rustup=
        add_rustup_alt=
        ;;
    *sh*)
        add_rustup="source \${HOME}/.cargo/env"
        add_rustup_alt=". \"\$HOME/.cargo/env\""
        ;;
    *)
        error "Detect UNKNOWN Current Interactive Shell (CISH): \"${CISH}\", thus skip brazil check."
        return 1
        ;;
    esac
    if [[ -n ${add_rustup} ]]; then
        if ! grep "^${add_rustup}\$" ${rcfile}; then
            if grep "^${add_rustup_alt}\$" ${rcfile}; then
                warning "rustup (alternative) has been included"
            else
                warning "rustup is not included"
            fi
        else
            pass "rustup has been included"
        fi
    fi
fi

if [[ -n $(which brazil) ]]; then
    case ${CISH} in
    *bash*)
        brazil_completion=${HOME}/.brazil_completion/bash_completion
        ;;
    *zsh*)
        brazil_completion=${HOME}/.brazil_completion/zsh_completion
        ;;
    *sh*)
        brazil_completion=${HOME}/.brazil_completion/bash_completion
        ;;
    *)
        error "Detect UNKNOWN Current Interactive Shell (CISH): \"${CISH}\", thus skip brazil check."
        return 1
        ;;
    esac
    if ! grep "^source ${brazil_completion}\$" ${rcfile}; then
        warning "brazil auto completion is not included"
    else
        pass "brazil auto completion has been included"
    fi
fi
