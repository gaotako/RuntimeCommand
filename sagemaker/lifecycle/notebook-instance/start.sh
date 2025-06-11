CISH=$(ps -p $$ | tail -1 | awk "{print \$NF}")

if [[ -f /opt/ml/metadata/resource-metadata.json ]]; then
    export HOME=/home/ec2-user
    export WORKSPACE=${HOME}/SageMaker
else
    echo -e "Can not start SageMaker initialization on Non-SageMaker instance."
    exit 1
fi

export XDG_ROOT=${WORKSPACE}/CrossDesktopGroup
export XDG_CONFIG_HOME=${XDG_ROOT}/config
export XDG_CACHE_HOME=${XDG_ROOT}/cache
export XDG_DATA_HOME=${XDG_ROOT}/local/share
export XDG_STATE_HOME=${XDG_ROOT}/local/state

export APP_ROOT=${WORKSPACE}/Application
export APP_DATA_HOME=${APP_ROOT}/data
export APP_BIN_HOME=${APP_ROOT}/bin

export SSH_HOME=${XDG_ROOT}/ssh

rm -rf ${SSH_HOME}
rm -rf ${HOME}/.ssh
ln -s ${SSH_HOME} ${HOME}/.ssh

export RC_ROOT=${WORKSPACE}/RuntimeCommandReadOnly
if [[ -d ${WORKSPACE}/RuntimeCommand ]]; then
    export RC_ROOT=${WORKSPACE}/RuntimeCommand/src/RuntimeCommand
fi

location=$(pwd)
cd ${RC_ROOT}
git pull
cd ${location}

export CODE_SERVER_ROOT=${WORKSPACE}/CodeServer
export CODE_SERVER_VERSION=0.2.0
export CODE_SERVER_PACKAGE=${CODE_SERVER_ROOT}/amazon-sagemaker-codeserver
export CODE_SERVER_APPLICATION=${APP_DATA_HOME}/cs

location=$(pwd)
cd ${CODE_SERVER_PACKAGE}/install-scripts/notebook-instances
./setup-codeserver.sh
cd ${location}

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
    exit 1
    ;;
esac