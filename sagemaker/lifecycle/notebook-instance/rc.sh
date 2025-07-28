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

args=()
coldstart=0
while [[ $# -gt 0 ]]; do
    case ${1} in
    -C|--coldstart)
        coldstart=1
        shift 1
        ;;
    *)
        args+=("${1}")
        shift 1
        ;;
    esac
done
if [[ ${#args[@]} -gt 0 ]]; then
    set -- "${args[@]}"
fi

if [[ -f /opt/ml/metadata/resource-metadata.json ]]; then
    export HOME=/home/ec2-user
    export WORKSPACE=${HOME}/SageMaker
else
    error "Can not execute SageMaker runtime command on Non-SageMaker instance."
    return 1
fi

case ${cish} in
*bash*)
    shdir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
    ;;
*zsh*)
    shdir=${0:a:h}
    ;;
*sh*)
    shdir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
    ;;
*)
    error "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus script directory can not be detected."
    return 1
    ;;
esac

if [[ -z ${RC_TOP} ]]; then
    export RC_TOP=${WORKSPACE}/RuntimeCommandReadOnly
    if [[ -d ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand ]]; then
        export RC_TOP=${WORKSPACE}/RuntimeCommand
    fi
fi
export RC_ROOT=${RC_TOP}/src/RuntimeCommand

export RC_COMMAND_BOOT="source ${RC_ROOT}/sagemaker/lifecycle/notebook-instance/rc.sh"
if [[ ${coldstart} -eq 0 ]]; then
    source ${shdir}/../../../unix/rc.sh
else
    source ${shdir}/../../../unix/rc.sh -C
fi
if [[ $? -ne 0 ]]; then
    return 1
fi

case ${cish} in
*bash*)
    rcfile=bashrc
    ;;
*zsh*)
    rcfile=zshrc
    ;;
*sh*)
    rcfile=bashrc
    ;;
*)
    error "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus rc file is not defined."
    return 1
    ;;
esac

if [[ ! -f ${HOME}/.profile ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "Runtime command script entrance \"${HOME}/.${cish}\" is not ready."
        return 1
    else
        rm -f ${HOME}/.profile
        echo "source ${HOME}/.${rcfile}" > ${HOME}/.profile
    fi
fi

export CODE_SERVER_SAGEMAKER_SETUP_ROOT=${WORKSPACE}/CodeServerSageMakerSetup
export CODE_SERVER_SAGEMAKER_SETUP_PACKAGE=${CODE_SERVER_SAGEMAKER_SETUP_ROOT}/amazon-sagemaker-codeserver

if [[ ! ( -L ${APP_DATA_HOME}/cs/bin/code-server && -f $(readlink -f ${APP_DATA_HOME}/cs/bin/code-server)) ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        echo "Code Server \"${APP_DATA_HOME}/cs/bin/code-server\" is not ready, thus Code Server runtime command is skipped."
    else
        rm -rf ${APP_DATA_HOME}/cs
        conda update -n base -c anaconda conda -y

        export READ_GITHUB_RELEASE_METADATA="python ${shdir}/python/read_github_release_metadata.py"

        export CODE_SERVER_SAGEMAKER_SETUP_VERSION=
        if [[ -z ${CODE_SERVER_SAGEMAKER_SETUP_VERSION} ]]; then
            export CODE_SERVER_SAGEMAKER_SETUP_VERSION=$(${READ_GITHUB_RELEASE_METADATA} "$(curl --silent https://api.github.com/repos/aws-samples/amazon-sagemaker-codeserver/releases/latest)" | grep tag_name | awk "{print \$2;}")
        fi
        export CODE_SERVER_SAGEMAKER_SETUP_VERSION=${CODE_SERVER_SAGEMAKER_SETUP_VERSION#v}

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
                cat ${name}.backup.${extension} >${filename}

                sed -i -e "s/^export XDG_DATA_HOME=\\\$XDG_DATA_HOME\$/#export XDG_DATA_HOME=\$XDG_DATA_HOME/g" ${filename}
                sed -i -e "s/^export XDG_CONFIG_HOME=\\\$XDG_CONFIG_HOME\$/#export XDG_CONFIG_HOME=\$XDG_CONFIG_HOME/g" ${filename}

                grep -q -F -x "CODE_SERVER_INSTALL_LOC=\"/home/ec2-user/SageMaker/.cs\"" ${filename} || (echo "CODE_SERVER_INSTALL_LOC template not match!" && return 1)
                grep -q -F -x "XDG_DATA_HOME=\"/home/ec2-user/SageMaker/.xdg/data\"" ${filename} || (echo "XDG_DATA_HOME template not match!" && return 1)
                grep -q -F -x "XDG_CONFIG_HOME=\"/home/ec2-user/SageMaker/.xdg/config\"" ${filename} || (echo "XDG_CONFIG_HOME template not match!" && return 1)
                grep -q -F -x "CONDA_ENV_LOCATION='/home/ec2-user/SageMaker/.cs/conda/envs/codeserver_py39'" ${filename} || (echo "CONDA_ENV_LOCATION template not match!" && return 1)

                sed -i -e "s/^CODE_SERVER_INSTALL_LOC=\"\/home\/ec2-user\/SageMaker\/.cs\"\$/CODE_SERVER_INSTALL_LOC=\"${CODE_SERVER_APPLICATION//\//\\/}\"/g" ${filename}
                sed -i -e "s/^XDG_DATA_HOME=\"\/home\/ec2-user\/SageMaker\/\.xdg\/data\"\$/XDG_DATA_HOME=\"${XDG_DATA_HOME//\//\\/}\"/g" ${filename}
                sed -i -e "s/^XDG_CONFIG_HOME=\"\/home\/ec2-user\/SageMaker\/\.xdg\/config\"\$/XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME//\//\\/}\"/g" ${filename}
                sed -i -e "s/^CONDA_ENV_LOCATION='\/home\/ec2-user\/SageMaker\/\.cs\/conda\/envs\/codeserver_py39'\$/CONDA_ENV_LOCATION='${CODE_SERVER_APPLICATION//\//\\/}\/conda\/envs\/cs'/g" ${filename}

                if [[ ${filename} != uninstall-codeserver.sh ]]; then
                    grep -q -F -x "CODE_SERVER_VERSION=\"4.16.1\"" ${filename} || (echo "CODE_SERVER_VERSION template not match!" && return 1)

                    sed -i -e "s/^CODE_SERVER_VERSION=\"4\.16\.1\"\$/CODE_SERVER_VERSION=\"${CODE_SERVER_VERSION}\"/g" ${filename}
                fi

                if [[ ${filename} == install-codeserver.sh ]]; then
                    grep -q -F -x "CONDA_ENV_PYTHON_VERSION=\"3.9\"" ${filename} || (echo "CONDA_ENV_PYTHON_VERSION template not match!" && return 1)

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

        conda clean --all -y

        location=$(pwd)
        cd ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances
        ./setup-codeserver.sh
        cd ${location}
    fi
fi
