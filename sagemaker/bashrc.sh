# Register path variables.
export CONDA="/home/ec2-user/anaconda3"
export PROJECT=
export STAGE=
export VIRENV="${HOME}/SageMaker/${PROJECT}/conda/${STAGE}"

# Raise error if runtime information is not fully provided.
if [[ -z ${HOME} ]]; then
    # Focusing project name for SageMaker running should be defined.
    echo -e "\033[96mwarning\033[0m: Home directory has not been claimed for bashrc."
fi
if [[ -z ${PROJECT} ]]; then
    # Focusing project name for SageMaker running should be defined.
    echo -e "\033[96mwarning\033[0m: SageMaker focusing project name in not defined in bashrc."
fi
if [[ -z ${STAGE} ]]; then
    # Focusing project working stage should be defined.
    echo -e "\033[96mwarning\033[0m: SageMaker focusing project working stage in not defined in bashrc."
fi

# Customized runtime commands.
. ${HOME}/SageMaker/RuntimeCommand/shrc