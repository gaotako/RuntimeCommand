# Register path variables.
export CONDA="/home/ec2-user/anaconda3"
export PROJECT=
export STAGE=
export VIRENV="${HOME}/SageMaker/${PROJECT}/conda/${STAGE}"

# Raise error if runtime information is not fully provided.
if [[ -z ${HOME} ]]; then
    # Focusing project name for SageMaker running should be defined.
    echo "error: Home directory has not been claimed for bashrc."
    exit 1
fi
if [[ -z ${PROJECT} ]]; then
    # Focusing project name for SageMaker running should be defined.
    echo "error: SageMaker focusing project name in not defined in bashrc."
    exit 1
fi
if [[ -z ${STAGE} ]]; then
    # Focusing project working stage should be defined.
    echo "error: SageMaker focusing project working stage in not defined in bashrc."
    exit 1
fi

# Customized runtime commands.
. ${HOME}/SageMaker/RuntimeCommand/shrc