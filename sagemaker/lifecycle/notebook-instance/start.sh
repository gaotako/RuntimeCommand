export HOME=/home/ec2-user
export SAGEMAKER=${HOME}/SageMaker

export XDG_ROOT=${SAGEMAKER}/CrossDesktopGroup
export XDG_CONFIG_HOME=${XDG_ROOT}/config
export XDG_CACHE_HOME=${XDG_ROOT}/cache
export XDG_DATA_HOME=${XDG_ROOT}/local/share
export XDG_STATE_HOME=${XDG_ROOT}/local/state

export APP_ROOT=${SAGEMAKER}/Application
export APP_DATA_HOME=${APP_ROOT}/data
export APP_BIN_HOME=${APP_ROOT}/bin

export SSH_HOME=${XDG_ROOT}/ssh

rm -rf ${SSH_HOME}/*
cp -r ${HOME}/.ssh/* ${SSH_HOME}

export RC_ROOT=${SAGEMAKER}/RuntimeCommandReadOnly

location=$(pwd)
cd ${RC_ROOT}
git pull
cd ${location}

export CODE_SERVER_ROOT=${SAGEMAKER}/CodeServer
export CODE_SERVER_VERSION=0.2.0
export CODE_SERVER_PACKAGE=${CODE_SERVER_ROOT}/amazon-sagemaker-codeserver
export CODE_SERVER_APPLICATION=${APP_DATA_HOME}/cs

location=$(pwd)
cd ${CODE_SERVER_PACKAGE}/install-scripts/notebook-instances
./setup-codeserver.sh
cd ${location}

eval "$(${APP_BIN_HOME}/mise activate bash)"

cp 