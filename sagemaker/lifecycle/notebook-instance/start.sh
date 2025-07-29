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

if [[ -f /opt/ml/metadata/resource-metadata.json ]]; then
    export HOME=/home/ec2-user
    export WORKSPACE=${HOME}/SageMaker
else
    error "Can not execute SageMaker runtime command on Non-SageMaker instance."
    return 1 2>/dev/null || exit 1
fi

export RC_TOP=${WORKSPACE}/RuntimeCommandReadOnly
export RC_ROOT=${RC_TOP}/src/RuntimeCommand
if [[ -d ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand ]]; then
    export RC_TOP=${WORKSPACE}/RuntimeCommand
    export RC_ROOT=${RC_TOP}/src/RuntimeCommand
fi
if [[ ! -d ${RC_ROOT} ]]; then
    error "Runtime command from \"https://github.com/gaotako/RuntimeCommand\" must be manually configured."
    return 1 2>/dev/null || exit 1
fi

export SSH_HOME=${RC_TOP}/ssh
export AWS_HOME=${RC_TOP}/aws

mkdir -p ${SSH_HOME}
if [[ ! -L ${HOME}/.ssh || $(readlink -f ${HOME}/.ssh) != $(readlink -f ${SSH_HOME}) ]]; then
    if [[ -n $(ls ${HOME}/.ssh 2>/dev/null) ]]; then
        cp ${HOME}/.ssh/* ${SSH_HOME}
    fi
    rm -rf ${HOME}/.ssh
    ln -s ${SSH_HOME} ${HOME}/.ssh
fi

mkdir -p ${AWS_HOME}
if [[ ! -L ${HOME}/.aws || $(readlink -f ${HOME}/.aws) != $(readlink -f ${AWS_HOME}) ]]; then
    if [[ -n $(ls ${HOME}/.aws 2>/dev/null) ]]; then
        cp ${HOME}/.aws/* ${AWS_HOME}
    fi
    rm -rf ${HOME}/.aws
    ln -s ${AWS_HOME} ${HOME}/.aws
fi

if [[ ! -f ${HOME}/.profile ]]; then
    touch ${HOME}/.profile
fi
if [[ ! -f ${HOME}/.bashrc ]]; then
    touch ${HOME}/.bashrc
fi
: > ${HOME}/.profile
: > ${HOME}/.bashrc

if [[ ! -L ${RC_TOP}/bashrc.sh || $(readlink -f ${RC_TOP}/bashrc.sh) != $(readlink -f ${HOME}/.bashrc) ]]; then
    rm -rf ${RC_TOP}/bashrc.sh
    ln -s ${HOME}/.bashrc ${RC_TOP}/bashrc.sh
fi

command="source ${HOME}/.bashrc"
if [[ -n ${command} && -z $(grep "^${command}$" ${HOME}/.profile) ]]; then
    echo ${command} >>${HOME}/.profile
fi

command="source ${RC_ROOT}/sagemaker/lifecycle/notebook-instance/rc.sh"
if [[ -n ${command} && -z $(grep "^${command}$" ${RC_TOP}/bashrc.sh) ]]; then
    echo ${command} >>${HOME}/.bashrc
fi

export CODE_SERVER_SAGEMAKER_SETUP_ROOT=${WORKSPACE}/CodeServerSageMakerSetup
export CODE_SERVER_SAGEMAKER_SETUP_PACKAGE=${CODE_SERVER_SAGEMAKER_SETUP_ROOT}/amazon-sagemaker-codeserver

if [[ -f ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/setup-codeserver.sh ]]; then
    ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/setup-codeserver.sh
    if [[ $? -ne 0 ]]; then
        echo -e "Fail to setup Code Server, thus skip it."
    fi
fi