# Reset command lien head.
#
# Args
# ----
#
# Returns
# -------
_PS_() {
    # Local variables for special keyword symbols.
    local reset
    local cyan
    local brightgreen
    local brightblue
    local brightmagenta
    local yellow
    local brightyellow
    local brightred
    local newline

    # Define keyword symbols for all supporting shells.
    reset=$'\e[0m'
    cyan=$'\e[36m'
    brightgreen=$'\e[92m'
    brightblue=$'\e[94m'
    brightmagenta=$'\e[95m'
    yellow=$'\e[33m'
    brightyellow=$'\e[93m'
    brightred=$'\e[91m'
    newline=$'\n'

    # Local variable to store the string of command line head.
    local shell
    local cmdhd

    # Command line head construction will be different according to running shell.
    shell=$(ps -p $$ | tail -1 | awk "{print \$NF}")
    case ${shell} in
    *bash*)
        # Bash requires explicit operation to enable string variables in command line head.
        shopt -s promptvars

        # Command line head for Bash.
        echo -e "Detect shell: \"${brightred}${shell}${reset}\" (bash)."
        cmdhd=
        cmdhd="${cmdhd}#${cyan}\#${reset}"
        cmdhd="${cmdhd} ${brightgreen}\u${reset}"
        cmdhd="${cmdhd}@${brightblue}\h${reset}"
        cmdhd="${cmdhd}[${brightmagenta}${STY#*.}${reset}]"
        cmdhd="${cmdhd}:${yellow}\w${reset}"
        cmdhd="${cmdhd}|${brightyellow}\W${reset}"
        ;;
    *zsh*)
        # Command line head for Zsh.
        echo -e "Detect shell: \"${brightred}${shell}${reset}\" (zsh)."
        cmdhd=
        cmdhd="${cmdhd}#${cyan}%h${reset}"
        cmdhd="${cmdhd} ${brightgreen}%n${reset}"
        cmdhd="${cmdhd}@${brightblue}%m${reset}"
        cmdhd="${cmdhd}[${brightmagenta}${STY#*.}${reset}]"
        cmdhd="${cmdhd}:${yellow}%~${reset}"
        cmdhd="${cmdhd}|${brightyellow}%.${reset}"
        ;;
    *sh*)
        # If the shell is none of above items, we assume bash by default.
        # Bash requires explicit operation to enable string variables in command line head.
        shopt -s promptvars

        # Command line head for Bash.
        echo -e "Detect shell: \"${brightred}${shell}${reset}\" (~bash)."
        cmdhd=
        cmdhd="${cmdhd}#${cyan}\#${reset}"
        cmdhd="${cmdhd} ${brightgreen}\u${reset}"
        cmdhd="${cmdhd}@${brightblue}\h${reset}"
        cmdhd="${cmdhd}[${brightmagenta}${STY#*.}${reset}]"
        cmdhd="${cmdhd}:${yellow}\w${reset}"
        cmdhd="${cmdhd}|${brightyellow}\W${reset}"
        ;;
    *)
        # Use default command line head for unsupported shells.
        # Thus, skip final broadcasting.
        return
        ;;
    esac

    # Braodcast command line head.
    export PS1="${newline}${reset}${cmdhd}${reset}${newline}$ "
}


# Python full formatting.
#
# Args
# ----
#
# Returns
# -------
alias_python_format() {
    # Run isort, flake8 and black in order.
    python -m isort ${*} && python -m flake8 ${*} && python -m black ${*}
}

# Alias new commands.
#
# Args
# ----
#
# Returns
# -------
_ALIAS_() {
    # Commands related to listing directory contents of files and directories.
    alias lsc="ls --color"

    # Commands related to GPU and CUDA.
    # Only perform the aliases when GPU and CUDA are available.
    if [[ -n $(which nvcc 2>/dev/null) ]]; then
        # CUDA commands.
        alias gpustats="watch -n 0.1 nvidia-smi"
    fi

    # Commands related to Python.
    alias python-format="alias_python_format"
    alias python-type="python -m mypy"
    alias python-test="python -m pytest"
}

# Prepare CUDA.
#
# Args
# ----
#
# Returns
# -------
_CUDA_() {
    # On remote clusters, CUDA may be loaded by `module`.
    if [[ -n $(which module 2>/dev/null) ]]; then
        # Use `module` to load default CUDA.
        module load cuda
    fi
}

# Prepare Slurm.
#
# Args
# ----
#
# Returns
# -------
_SLURM_() {
    # On remote clusters, Slurm may be loaded by `module`.
    if [[ -n $(which module 2>/dev/null) ]]; then
        # Use `module` to load default Slurm.
        module load slurm
    fi

    # Some configurations are only allowed when Slurm is active.
    if [[ -n $(which slurm 2>/dev/null) ]]; then
        # Use customized Slurm queue log.
        export SQUEUE_FORMAT="%.10i %.9P %.8u %.28j %.2t %.10M"
    fi
}

# Prepare Conda.
#
# Args
# ----
#
# Returns
# -------
_CONDA_() {
    # Local variables.
    local __conda_setup
    local title

    # Skip conda initialization if conda root is not defined.
    [[ -z ${CONDA} ]] && return

    # Essential commands for conda initialization.
    # This is a copy from default conda initialization codes with slight modification to fit personal customization.
    __conda_setup="$("${CONDA}/bin/conda" shell.bash hook 2>/dev/null)"
    if [[ $? -eq 0 ]]; then
        # Execute codes provided in Conda setup failure return.
        eval "$__conda_setup"
    else
        # Conda setup is successful, proceed to initialization.
        # If Conda environment has customized initialization, then run it rather than take default operations.
        if [[ -f "${CONDA}/etc/profile.d/conda.sh" ]]; then
            # Run Conda environment initialization.
            . "${CONDA}/etc/profile.d/conda.sh"
        else
            # By default, add and prioritize Conda environment binaries into system path.
            export PATH="${CONDA}/bin:${PATH}"
        fi
    fi
    unset __conda_setup

    # Try three level of possible virtual environments.
    for title in "${VIRENV}" Default base; do
        # Test virtual environment title.
        if [[ -z "${title}" ]]; then
            # Skip empty title.
            continue
        fi

        # Try activate to activate the environment.
        conda activate "${title}"
        if [[ ${?} -eq 0 ]]; then
            # Early stop if previous activation is successful.
            continue
        fi
    done
}

# Reset terminal settings.
_PS_

# Enable essential softwares.
_CUDA_
_SLURM_

# Register essential commands.
_ALIAS_

# Enable virtual environments.
_CONDA_
