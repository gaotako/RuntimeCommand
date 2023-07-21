# Reset prompt shell header.
_PS1_() {
    #
    local cmdhd

    #
    shopt -s promptvars
    cmdhd=
    cmdhd="${cmdhd}#\033[36m\#\033[0m"
    cmdhd="${cmdhd} \033[92m\u\033[0m"
    cmdhd="${cmdhd}@\033[94m\h\033[0m"
    cmdhd="${cmdhd}[\033[95m${STY#*.}\033[0m]"
    cmdhd="${cmdhd}:\033[33m\w\033[0m"
    cmdhd="${cmdhd}|\033[93m\W\033[0m"
    export PS1="\n\033[0m${cmdhd}\033[0m\n$ "
}

# Alias new commands.
_ALIAS_() {
    #
    alias lsc="ls --color"

    #
    if [[ -n $(which nvcc 2>/dev/null) ]]; then
        #
        alias gpustats="watch -n 0.1 nvidia-smi"
    fi
}

# CUDA
_CUDA_() {
    #
    if [[ -n $(which module 2>/dev/null) ]]; then
        #
        module load cuda/11.7
    fi
}

# Slurm
_SLURM_() {
    #
    if [[ -n $(which module 2>/dev/null) ]]; then
        #
        module load slurm
    fi

    #
    if [[ -n $(which slurm 2>/dev/null) ]]; then
        # Use customized slurm queue log.
        export SQUEUE_FORMAT="%.10i %.9P %.8u %.28j %.2t %.10M"
    fi
}

# CONDA
_CONDA_() {
    # Essential for conda initialization.
    __conda_root="/usr/local/Caskroom/miniconda/base"
    __conda_setup="$("${__conda_root}/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"
    if [[ $? -eq 0 ]]; then
        #
        eval "$__conda_setup"
    else
        #
        if [[ -f "${__conda_root}/etc/profile.d/conda.sh" ]]; then
            #
            . "${__conda_root}/etc/profile.d/conda.sh"
        else
            # Prioritize this setting over system setting.
            export PATH="${__conda_root}/bin:${PATH}"
        fi
    fi
    unset __conda_setup

    #
    conda activate Default
}

# Reset terminal log.
_PS1_

# Enable essential softwares.
_CUDA_
_SLURM_

# Register essential commands.
_ALIAS_

# Enable virtual environment.
_CONDA_
