set -eux

if [[ -z ${HOME} ]]; then
    export HOME=/home/ec2-user
fi
if [[ -z ${SAGEMAKER} ]]; then
    export SAGEMAKER=${HOME}/SageMaker
fi

location=$(pwd)
cd ${RC_ROOT}
git pull
cd ${location}

export XDG_ROOT=${SAGEMAKER}/CrossDesktopGroup
export XDG_CONFIG_HOME=${XDG_ROOT}/config
export XDG_CACHE_HOME=${XDG_ROOT}/cache
export XDG_DATA_HOME=${XDG_ROOT}/local/share
export XDG_STATE_HOME=${XDG_ROOT}/local/state

mkdir -p ${XDG_CONFIG_HOME}
mkdir -p ${XDG_CACHE_HOME}
mkdir -p ${XDG_DATA_HOME}
mkdir -p ${XDG_STATE_HOME}

export APP_ROOT=${SAGEMAKER}/Application
export APP_DATA_HOME=${APP_ROOT}/data
export APP_BIN_HOME=${APP_ROOT}/bin

mkdir -p ${APP_DATA_HOME}
mkdir -p ${APP_BIN_HOME}

export SSH_HOME=${XDG_ROOT}/ssh

if [[ ! -f ${HOME}/.ssh/id_rsa ]]; then
    ssh-keygen -t rsa -q -f "${HOME}/.ssh/id_rsa" -N ""
fi

rm -rf ${SSH_HOME}/*
cp -r ${HOME}/.ssh/* ${SSH_HOME}

export RC_ROOT=${SAGEMAKER}/RuntimeCommandReadOnly

if [[ ! -d ${RC_ROOT} ]]; then
    git clone https://github.com/gaotako/RuntimeCommand.git ${RC_ROOT}
fi

export CODE_SERVER_ROOT=${SAGEMAKER}/CodeServer
export CODE_SERVER_VERSION=0.2.0
export CODE_SERVER_PACKAGE=${CODE_SERVER_ROOT}/amazon-sagemaker-codeserver
export CODE_SERVER_APPLICATION=${APP_DATA_HOME}/cs

if [[ ! -d ${CODE_SERVER_PACKAGE} ]]; then
    FILENAME=amazon-sagemaker-codeserver-${CODE_SERVER_VERSION}.tar.gz
    URL=https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v${CODE_SERVER_VERSION}/${FILENAME}
    curl -LO ${URL}
    tar -xvzf ${FILENAME}
    rm -f ${FILENAME}

    location=$(pwd)
    cd ${CODE_SERVER_PACKAGE}/install-scripts/notebook-instances
    for filename in install-codeserver.sh setup-codeserver.sh uninstall-codeserver.sh; do
        cp ${filename} ${filename}.backup
    done
    cd ${location}
fi

if [[ ! -d ${CODE_SERVER_APPLICATION} ]]; then
    location=$(pwd)
    cd ${CODE_SERVER_PACKAGE}/install-scripts/notebook-instances

    for filename in install-codeserver.sh setup-codeserver.sh uninstall-codeserver.sh; do
        cat ${filename}.backup > ${filename}
        sed -i -e "s/^CODE_SERVER_INSTALL_LOC=\"\/home\/ec2-user\/SageMaker\/.cs\"\$/CODE_SERVER_INSTALL_LOC=\"${CODE_SERVER_ROOT//\//\\/}\/cs\"/g" ${filename}
        sed -i -e "s/^XDG_DATA_HOME=\"\/home\/ec2-user\/SageMaker\/.xdg\/data\"\$/XDG_DATA_HOME=\"${XDG_DATA_HOME//\//\\/}\"/g" ${filename}
        sed -i -e "s/^XDG_CONFIG_HOME=\"\/home\/ec2-user\/SageMaker\/.xdg\/config\"\$/XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME//\//\\/}\"/g" ${filename}
        sed -i -e "s/^CONDA_ENV_LOCATION=\'\/home\/ec2-user\/SageMaker\/.cs\/conda\/envs\/codeserver_py39\'\$/CONDA_ENV_LOCATION=\'${CODE_SERVER_APPLICATION//\//\\/}\/conda\/envs\/codeserver_py39'/g" ${filename}
        sed -i -e "s/^export XDG_DATA_HOME=\\\$XDG_DATA_HOME\$/#export XDG_DATA_HOME=\$XDG_DATA_HOME/g" ${filename}
        sed -i -e "s/^export XDG_CONFIG_HOME=\\\$XDG_CONFIG_HOME\$/#export XDG_CONFIG_HOME=\$XDG_CONFIG_HOME/g" ${filename}
    done

    chmod +x install-codeserver.sh
    chmod +x setup-codeserver.sh
    chmod +x uninstall-codeserver.sh

    ./install-codeserver.sh

    cd ${location}
fi

location=$(pwd)
cd ${CODE_SERVER_PACKAGE}/install-scripts/notebook-instances
./setup-codeserver.sh
cd ${location}

if [[ ! -f ${APP_BIN_HOME}/mise ]]; then
    curl https://mise.run | MISE_INSTALL_PATH=${APP_BIN_HOME}/mise sh
fi
eval "$(${APP_BIN_HOME}/mise activate bash)"

mise install python@3.11 python@3.12