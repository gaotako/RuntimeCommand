set -eux

export CISH=$(ps -p $$ | tail -1 | awk "{print \$NF}")

if [[ -f /opt/ml/metadata/resource-metadata.json ]]; then
    export HOME=/home/ec2-user
    export WORKSPACE=${HOME}/SageMaker
else
    echo -e "Can not coldstart SageMaker setup on Non-SageMaker instance."
    exit 1
fi

rm -f ${WORKSPACE}/rc.sh

export XDG_ROOT=${WORKSPACE}/CrossDesktopGroup
export XDG_CONFIG_HOME=${XDG_ROOT}/config
export XDG_CACHE_HOME=${XDG_ROOT}/cache
export XDG_DATA_HOME=${XDG_ROOT}/local/share
export XDG_STATE_HOME=${XDG_ROOT}/local/state

rm -rf ${XDG_CONFIG_HOME}
rm -rf ${XDG_CACHE_HOME}
rm -rf ${XDG_DATA_HOME}
rm -rf ${XDG_STATE_HOME}

mkdir -p ${XDG_CONFIG_HOME}
mkdir -p ${XDG_CACHE_HOME}
mkdir -p ${XDG_DATA_HOME}
mkdir -p ${XDG_STATE_HOME}

export APP_ROOT=${WORKSPACE}/Application
export APP_DATA_HOME=${APP_ROOT}/data
export APP_BIN_HOME=${APP_ROOT}/bin

rm -rf ${APP_DATA_HOME}
rm -rf ${APP_BIN_HOME}

mkdir -p ${APP_DATA_HOME}
mkdir -p ${APP_BIN_HOME}

export SSH_HOME=${XDG_ROOT}/ssh

if [[ $(readlink -f ${HOME}/.ssh) != ${SSH_HOME} ]]; then
    rm -rf ${SSH_HOME}
    rm -rf ${HOME}/.ssh
    ln -s ${SSH_HOME} ${HOME}/.ssh
fi

export RC_ROOT=${WORKSPACE}/RuntimeCommandReadOnly

if [[ ! -d ${RC_ROOT} ]]; then
    git clone https://github.com/gaotako/RuntimeCommand.git ${RC_ROOT}
fi

export READ_GITHUB_RELEASE_METADATA="python ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand/sagemaker/lifecycle/notebook-instance/python/read_github_release_metadata.py" #!!!

location=$(pwd)
cd ${RC_ROOT}
git pull
cd ${location}

conda update -n base -c anaconda conda -y

export CODE_SERVER_SAGEMAKER_SETUP_ROOT=${WORKSPACE}/CodeServerSageMakerSetup
export CODE_SERVER_SAGEMAKER_SETUP_VERSION=
if [[ -z ${CODE_SERVER_SAGEMAKER_SETUP_VERSION} ]]; then
    export CODE_SERVER_SAGEMAKER_SETUP_VERSION=$(${READ_GITHUB_RELEASE_METADATA} "$(curl --silent https://api.github.com/repos/aws-samples/amazon-sagemaker-codeserver/releases/latest)" | grep tag_name | awk "{print \$2;}")
fi
export CODE_SERVER_SAGEMAKER_SETUP_VERSION=${CODE_SERVER_SAGEMAKER_SETUP_VERSION#v}
export CODE_SERVER_SAGEMAKER_SETUP_PACKAGE=${CODE_SERVER_SAGEMAKER_SETUP_ROOT}/amazon-sagemaker-codeserver

if [[ ! -d ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE} ]]; then
    location=$(pwd)
    mkdir -p ${CODE_SERVER_SAGEMAKER_SETUP_ROOT}
    cd ${CODE_SERVER_SAGEMAKER_SETUP_ROOT}

    filename=amazon-sagemaker-codeserver-${CODE_SERVER_SAGEMAKER_SETUP_VERSION}.tar.gz
    url=https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v${CODE_SERVER_SAGEMAKER_SETUP_VERSION}/${filename}
    curl -LO ${url}
    tar -xvzf ${filename}
    rm -f ${filename}

    cd ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances
    for filename in install-codeserver.sh setup-codeserver.sh uninstall-codeserver.sh; do
        name=${filename%.*}
        extension=${filename##*.}
        cp ${filename} ${name}.backup.${extension}
    done

    cd ${location}
fi

export CODE_SERVER_VERSION=4.16.1 # Due to glibc == 2.26 on AL2 (starting from 4.17.0 requires glibc >= 2.28) which is fixed for SageMaker
if [[ -z ${CODE_SERVER_VERSION} ]]; then
    export CODE_SERVER_VERSION=$(${READ_GITHUB_RELEASE_METADATA} "$(curl --silent https://api.github.com/repos/coder/code-server/releases/latest)" | grep tag_name | awk "{print \$2;}")
fi
export CODE_SERVER_VERSION=${CODE_SERVER_VERSION#v}
export CODE_SERVER_PYTHON_VERSION=3.11
export CODE_SERVER_APPLICATION=${APP_DATA_HOME}/cs

if [[ ! -d ${CODE_SERVER_APPLICATION} ]]; then
    location=$(pwd)
    cd ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances

    for filename in install-codeserver.sh setup-codeserver.sh uninstall-codeserver.sh; do
        name=${filename%.*}
        extension=${filename##*.}
        cat ${name}.backup.${extension} > ${filename}
        
        sed -i -e "s/^export XDG_DATA_HOME=\\\$XDG_DATA_HOME\$/#export XDG_DATA_HOME=\$XDG_DATA_HOME/g" ${filename}
        sed -i -e "s/^export XDG_CONFIG_HOME=\\\$XDG_CONFIG_HOME\$/#export XDG_CONFIG_HOME=\$XDG_CONFIG_HOME/g" ${filename}

        grep -q -F -x "CODE_SERVER_INSTALL_LOC=\"/home/ec2-user/SageMaker/.cs\"" ${filename} || ( echo "CODE_SERVER_INSTALL_LOC template not match!" && exit 1 )
        grep -q -F -x "XDG_DATA_HOME=\"/home/ec2-user/SageMaker/.xdg/data\"" ${filename} || ( echo "XDG_DATA_HOME template not match!" && exit 1 )
        grep -q -F -x "XDG_CONFIG_HOME=\"/home/ec2-user/SageMaker/.xdg/config\"" ${filename} || ( echo "XDG_CONFIG_HOME template not match!" && exit 1 )
        grep -q -F -x "CONDA_ENV_LOCATION='/home/ec2-user/SageMaker/.cs/conda/envs/codeserver_py39'" ${filename} || ( echo "CONDA_ENV_LOCATION template not match!" && exit 1 )

        sed -i -e "s/^CODE_SERVER_INSTALL_LOC=\"\/home\/ec2-user\/SageMaker\/.cs\"\$/CODE_SERVER_INSTALL_LOC=\"${CODE_SERVER_APPLICATION//\//\\/}\"/g" ${filename}
        sed -i -e "s/^XDG_DATA_HOME=\"\/home\/ec2-user\/SageMaker\/\.xdg\/data\"\$/XDG_DATA_HOME=\"${XDG_DATA_HOME//\//\\/}\"/g" ${filename}
        sed -i -e "s/^XDG_CONFIG_HOME=\"\/home\/ec2-user\/SageMaker\/\.xdg\/config\"\$/XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME//\//\\/}\"/g" ${filename}
        sed -i -e "s/^CONDA_ENV_LOCATION='\/home\/ec2-user\/SageMaker\/\.cs\/conda\/envs\/codeserver_py39'\$/CONDA_ENV_LOCATION='${CODE_SERVER_APPLICATION//\//\\/}\/conda\/envs\/cs'/g" ${filename}

        if [[ ${filename} != uninstall-codeserver.sh ]]; then
            grep -q -F -x "CODE_SERVER_VERSION=\"4.16.1\"" ${filename} || ( echo "CODE_SERVER_VERSION template not match!" && exit 1 )
            
            sed -i -e "s/^CODE_SERVER_VERSION=\"4\.16\.1\"\$/CODE_SERVER_VERSION=\"${CODE_SERVER_VERSION}\"/g" ${filename}
        fi

        if [[ ${filename} == install-codeserver.sh ]]; then
            grep -q -F -x "CONDA_ENV_PYTHON_VERSION=\"3.9\"" ${filename} || ( echo "CONDA_ENV_PYTHON_VERSION template not match!" && exit 1 )
            
            sed -i -e "s/^CONDA_ENV_PYTHON_VERSION=\"3\.9\"\$/CONDA_ENV_PYTHON_VERSION=\"${CODE_SERVER_PYTHON_VERSION}\"/g" ${filename}
        fi
    done

    chmod +x install-codeserver.sh
    chmod +x setup-codeserver.sh
    chmod +x uninstall-codeserver.sh

    rm -rf ${CODE_SERVER_APPLICATION}/conda/envs/cs/*
    ./install-codeserver.sh

    cd ${location}
fi

location=$(pwd)
cd ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances
./setup-codeserver.sh
cd ${location}

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

mise install python@3.12 python@3.11 python@3.10 python@3.9

ln -s ${RC_ROOT}/unix/rc.sh ${WORKSPACE}/rc.sh
case ${CISH} in
*bash*)
    rm -f ${HOME}/.profile ${HOME}/.bashrc
    ln -s ${WORKSPACE}/rc.sh ${HOME}/.profile
    ln -s ${WORKSPACE}/rc.sh ${HOME}/.bashrc
    ;;
*zsh*)
    rm -f ${HOME}/.profile ${HOME}/.zshrc
    ln -s ${WORKSPACE}/rc.sh ${HOME}/.profile
    ln -s ${WORKSPACE}/rc.sh ${HOME}/.zshrc
    ;;
*sh*)
    rm -f ${HOME}/.profile ${HOME}/.bashrc
    ln -s ${WORKSPACE}/rc.sh ${HOME}/.profile
    ln -s ${WORKSPACE}/rc.sh ${HOME}/.bashrc
    ;;
*)
    echo -e "Detect UNKNOWN Current Interactive Shell (CISH): \"${CISH}\", thus Runtime Command is not registered."
    ;;
esac