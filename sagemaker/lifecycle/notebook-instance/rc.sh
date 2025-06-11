if [[ -f /opt/ml/metadata/resource-metadata.json ]]; then
    export HOME=/home/ec2-user
    export SAGEMAKER=${HOME}/SageMaker
else
    echo -e "Can not execute SageMaker runtime command on Non-SageMaker instance."
    exit 1
fi

export APP_ROOT=${WORKSPACE}/Application
export APP_DATA_HOME=${APP_ROOT}/data

export CODE_SERVER_ROOT=${WORKSPACE}/CodeServer
export CODE_SERVER_VERSION=0.2.0
export CODE_SERVER_PACKAGE=${CODE_SERVER_ROOT}/amazon-sagemaker-codeserver
export CODE_SERVER_APPLICATION=${APP_DATA_HOME}/cs
