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
    return 1 2>/dev/null || exit 1
    ;;
esac

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
    return 1 2>/dev/null || exit 1
fi

if [[ -z ${RC_TOP} ]]; then
    export RC_TOP=${WORKSPACE}/RuntimeCommandReadOnly
    if [[ -d ${WORKSPACE}/RuntimeCommand/src/RuntimeCommand ]]; then
        export RC_TOP=${WORKSPACE}/RuntimeCommand
    fi
fi
export RC_ROOT=${RC_TOP}/src/RuntimeCommand

export RC_COMMAND_BOOT="source ${RC_ROOT}/sagemaker/lifecycle/notebook-instance/rc.sh"
if [[ ${coldstart} -eq 0 ]]; then
    source ${shdir}/../../../unix/rc.sh -M
else
    source ${shdir}/../../../unix/rc.sh -M -C
fi
if [[ $? -ne 0 ]]; then
    return 1 2>/dev/null || exit 1
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
    return 1 2>/dev/null || exit 1
    ;;
esac

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
    return 1 2>/dev/null || exit 1
    ;;
esac

if [[ ! -f ${HOME}/.profile ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        error "Runtime command script entrance \"${HOME}/.${cish}\" is not ready."
        return 1 2>/dev/null || exit 1
    else
        rm -f ${HOME}/.profile
        echo "source ${HOME}/.${rcfile}" > ${HOME}/.profile
    fi
fi

export JUPYTER_CONFIG=${HOME}/.jupyter/jupyter_notebook_config.py

export CODE_SERVER_SAGEMAKER_SETUP_ROOT=${WORKSPACE}/CodeServerSageMakerSetup
export CODE_SERVER_SAGEMAKER_SETUP_PACKAGE=${CODE_SERVER_SAGEMAKER_SETUP_ROOT}/amazon-sagemaker-codeserver
export CODE_SERVER_APPLICATION=${APP_DATA_HOME}/cs
export CODE_SERVER=${CODE_SERVER_APPLICATION}/bin/code-server
export CODE_SERVER_PYTHON_VERSION=3.11

if [[ ! ( -L ${CODE_SERVER} && -f $(readlink -f ${CODE_SERVER}) ) ]]; then
    if [[ ${coldstart} -eq 0 ]]; then
        echo "Code Server \"${CODE_SERVER}\" is not ready, thus Code Server runtime command is skipped."
    else
        export READ_GITHUB_RELEASE_METADATA="python ${shdir}/python/read_github_release_metadata.py"

        export CODE_SERVER_SAGEMAKER_SETUP_VERSION=
        if [[ -z ${CODE_SERVER_SAGEMAKER_SETUP_VERSION} ]]; then
            export CODE_SERVER_SAGEMAKER_SETUP_VERSION=$(${READ_GITHUB_RELEASE_METADATA} "$(curl --silent https://api.github.com/repos/aws-samples/amazon-sagemaker-codeserver/releases/latest)" | grep tag_name | awk "{print \$2;}")
        fi
        export CODE_SERVER_SAGEMAKER_SETUP_VERSION=${CODE_SERVER_SAGEMAKER_SETUP_VERSION#v}

        export CODE_SERVER_VERSION=
        if [[ -z ${CODE_SERVER_VERSION} ]]; then
            export CODE_SERVER_VERSION=$(${READ_GITHUB_RELEASE_METADATA} "$(curl --silent https://api.github.com/repos/coder/code-server/releases/latest)" | grep tag_name | awk "{print \$2;}")
        fi
        warning "Due to glibc == 2.26 on AL2 (starting from 4.17.0 requires glibc >= 2.28) which is fixed for SageMaker, Code Server must be no later than 4.16.1."
        export CODE_SERVER_VERSION=4.16.1
        export CODE_SERVER_VERSION=${CODE_SERVER_VERSION#v}

        rm -rf ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}

        rm -rf ${CODE_SERVER_APPLICATION}
        rm -rf ${XDG_DATA_HOME}/code-server
        rm -rf ${XDG_CONFIG_HOME}/code-server
        if [[ -f ${JUPYTER_CONFIG} && -n $(grep "${CODE_SERVER_APPLICATION}/bin/code-server" ${JUPYTER_CONFIG}) ]]; then
            error "Previous Code Server setup is not completely deleted (NOT commented) from \"${JUPYTER_CONFIG}\"."
            return 1 2>/dev/null || exit 1
        fi

        rm -rf /home/ec2-user/SageMaker/.cs
        rm -rf /home/ec2-user/SageMaker/.xdg/data/code-server
        rm -rf /home/ec2-user/SageMaker/.xdg/config/code-server
        if [[ -f ${JUPYTER_CONFIG} && -n $(grep "/home/ec2-user/SageMaker/.cs/bin/code-server" ${JUPYTER_CONFIG}) ]]; then
            error "Previous Code Server setup is not completely deleted (NOT commented) from \"${JUPYTER_CONFIG}\"."
            return 1 2>/dev/null || exit 1
        fi

        mkdir -p ${CODE_SERVER_SAGEMAKER_SETUP_ROOT}

        filename=amazon-sagemaker-codeserver-${CODE_SERVER_SAGEMAKER_SETUP_VERSION}.tar.gz
        url=https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v${CODE_SERVER_SAGEMAKER_SETUP_VERSION}/${filename}
        curl -Lo ${CODE_SERVER_SAGEMAKER_SETUP_ROOT}/${filename} ${url} 
        tar -xvzf ${CODE_SERVER_SAGEMAKER_SETUP_ROOT}/${filename} -C $(dirname ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE})
        rm -f ${filename}

        for filename in install-codeserver.sh setup-codeserver.sh uninstall-codeserver.sh; do
            name=${filename%.*}
            extension=${filename##*.}
            path=${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/${filename}
            [[ -f ${path} ]] || ( error "Code Server setup file \"${path}\" does not exist." && ( return 1 2>/dev/null || exit 1 ) )
            rm -rf ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/${name}.backup.${extension}
            cp ${path} ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/${name}.backup.${extension}
        done

        for filename in install-codeserver.sh setup-codeserver.sh uninstall-codeserver.sh; do
            name=${filename%.*}
            extension=${filename##*.}
            path=${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/${filename}
            cat ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/${name}.backup.${extension} >${path}

            grep -q "^CODE_SERVER_INSTALL_LOC=\"/home/ec2-user/SageMaker/.cs\"\$" ${path} || ( echo "CODE_SERVER_INSTALL_LOC template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )
            grep -q "^XDG_DATA_HOME=\"/home/ec2-user/SageMaker/.xdg/data\"\$" ${path} || ( echo "XDG_DATA_HOME template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )
            grep -q "^XDG_CONFIG_HOME=\"/home/ec2-user/SageMaker/.xdg/config\"\$" ${path} || ( echo "XDG_CONFIG_HOME template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )
            grep -q "^CONDA_ENV_LOCATION='/home/ec2-user/SageMaker/.cs/conda/envs/codeserver_py39'\$" ${path} || (echo "CONDA_ENV_LOCATION template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )

            sed -i -e "s/^CODE_SERVER_INSTALL_LOC=\"\/home\/ec2-user\/SageMaker\/.cs\"\$/CODE_SERVER_INSTALL_LOC=\"${CODE_SERVER_APPLICATION//\//\\/}\"/g" ${path}
            sed -i -e "s/^XDG_DATA_HOME=\"\/home\/ec2-user\/SageMaker\/\.xdg\/data\"\$/XDG_DATA_HOME=\"${XDG_DATA_HOME//\//\\/}\"/g" ${path}
            sed -i -e "s/^XDG_CONFIG_HOME=\"\/home\/ec2-user\/SageMaker\/\.xdg\/config\"\$/XDG_CONFIG_HOME=\"${XDG_CONFIG_HOME//\//\\/}\"/g" ${path}
            sed -i -e "s/^CONDA_ENV_LOCATION='\/home\/ec2-user\/SageMaker\/\.cs\/conda\/envs\/codeserver_py39'\$/CONDA_ENV_LOCATION='${CODE_SERVER_APPLICATION//\//\\/}\/conda\/envs\/cs'/g" ${path}

            if [[ ${filename} != uninstall-codeserver.sh ]]; then
                grep -q "^CODE_SERVER_VERSION=\"4\.16\.1\"\$" ${path} || ( echo "CODE_SERVER_VERSION template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )
                grep -q "^export XDG_DATA_HOME=\\\$XDG_DATA_HOME$" ${path} || ( echo "XDG_DATA_HOME exporting template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )
                grep -q "^export XDG_CONFIG_HOME=\\\$XDG_CONFIG_HOME$" ${path} || ( echo "XDG_CONFIG_HOME exporting template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )

                sed -i -e "s/^CODE_SERVER_VERSION=\"4\.16\.1\"\$/CODE_SERVER_VERSION=\"${CODE_SERVER_VERSION}\"/g" ${path}
                sed -i -e "s/^export XDG_DATA_HOME=\\\$XDG_DATA_HOME\$/#export XDG_DATA_HOME=\$XDG_DATA_HOME/g" ${path}
                sed -i -e "s/^export XDG_CONFIG_HOME=\\\$XDG_CONFIG_HOME\$/#export XDG_CONFIG_HOME=\$XDG_CONFIG_HOME/g" ${path}
            fi

            if [[ ${filename} == install-codeserver.sh ]]; then
                grep -q "^CONDA_ENV_PYTHON_VERSION=\"3\.9\"\$" ${path} || ( echo "CONDA_ENV_PYTHON_VERSION template is not match in \"${path}\"." && ( return 1 2>/dev/null || exit 1 ) )

                sed -i -e "s/^CONDA_ENV_PYTHON_VERSION=\"3\.9\"\$/CONDA_ENV_PYTHON_VERSION=\"${CODE_SERVER_PYTHON_VERSION}\"/g" ${path}
            fi
        done

        chmod +x ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/install-codeserver.sh
        chmod +x ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/setup-codeserver.sh
        chmod +x ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/uninstall-codeserver.sh

        conda update -n base -c anaconda conda -y
        ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/install-codeserver.sh
        conda clean --all -y

        if [[ ${coldstart} -ne 0 ]]; then
            source ${shdir}/cs/coldstart.sh
        fi

        ${CODE_SERVER_SAGEMAKER_SETUP_PACKAGE}/install-scripts/notebook-instances/setup-codeserver.sh
    fi
fi

source ${shdir}/../../../unix/mise.sh