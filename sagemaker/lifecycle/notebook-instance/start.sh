if [[ -f /opt/ml/metadata/resource-metadata.json ]]; then
    export HOME=/home/ec2-user
    export WORKSPACE=${HOME}/SageMaker
else
    error "Can not execute SageMaker runtime command on Non-SageMaker instance."
    return 1
fi

export RC_TOP=${WORKSPACE}/RuntimeCommandReadOnly
export RC_ROOT=${RC_TOP}/src/RuntimeCommand
if [[ -d ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand ]]; then
    export RC_TOP=${WORKSPACE}/RuntimeCommand
    export RC_ROOT=${RC_TOP}/src/RuntimeCommand
fi
if [[ ! -d ${RC_ROOT} ]]; then
    mkdir -p $(dirname ${RC_ROOT})
    git clone https://github.com/gaotako/RuntimeCommand.git ${RC_ROOT}
fi

if [[ ! -f ${HOME}/.bashrc ]]; then
    touch ${HOME}/.bashrc
fi
if [[ ! -L ${RC_TOP}/bashrc.sh || $(readlink -f ${RC_TOP}/bashrc.sh) != ${HOME}/.bashrc ]]; then
    rm -rf ${RC_TOP}/bashrc.sh
    ln -s ${HOME}/.bashrc ${RC_TOP}/bashrc.sh
fi

command="source ${HOME}/.bashrc"
if [[ -n ${command} && -z $(grep "^${command}$" ${RC_TOP}/bashrc.sh) ]]; then
    echo ${profille} >>${HOME}/.bashrc
fi

export CODE_SERVER_SAGEMAKER_SETUP_ROOT=${WORKSPACE}/CodeServerSageMakerSetup
export CODE_SERVER_SAGEMAKER_SETUP_PACKAGE=${CODE_SERVER_SAGEMAKER_SETUP_ROOT}/amazon-sagemaker-codeserver

if [[ -f ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/setup-codeserver.sh ]]; then
    location=$(pwd)
    cd ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances
    ./setup-codeserver.sh
    cd ${location}
fi