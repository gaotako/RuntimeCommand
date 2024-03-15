# If runtime command is predefined by system, activate it first.
if [[ -f ~/.bashrc ]]; then
    # Activate system configuration runtime command.
    . ~/.bashrc
fi

# Register path variables.
export PATH="${PATH}:${HOME}/.local/bin:${HOME}/bin"