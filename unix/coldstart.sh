cish=$(ps -o comm -p $$ | tail -1 | awk "{print \$NF}")

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
    echo -e "Detect UNKNOWN Current Interactive Shell (CISH): \"${cish}\", thus script directory can not be detected."
    return 1
    ;;
esac

source ${shdir}/rc.sh

case ${cish} in
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
    error "Detect UNKNOWN Current Interactive Shell (CISH): \"${cish}\", thus rc file is not defined."
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
    case ${cish} in
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
        error "Detect UNKNOWN Current Interactive Shell (CISH): \"${cish}\", thus skip brazil check."
        return 1
        ;;
    esac
    if ! grep "^source ${brazil_completion}\$" ${rcfile}; then
        warning "brazil auto completion is not included"
    else
        pass "brazil auto completion has been included"
    fi
fi
