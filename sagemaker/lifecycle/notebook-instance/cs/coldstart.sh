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
    echo -e "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus this script directory can not be detected."
    return 1 2>/dev/null || exit 1
    ;;
esac

[[ -d ${RC_ROOT} ]] || ( error "Runtime command root directory \"${RC_ROOT}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
[[ -d ${XDG_CONFIG_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_CONFIG_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )
[[ -d ${XDG_DATA_HOME} ]] || ( error "Runtime command dependent directory \"${XDG_DATA_HOME}\" is not ready." && ( return 1 2>/dev/null || exit 1 ) )

export CODE_SERVER_APPLICATION=${APP_DATA_HOME}/cs
export CODE_SERVER=${CODE_SERVER_APPLICATION}/bin/code-server
export CODE_SERVER_SETTINGS_ROOT=${XDG_DATA_HOME}/code-server
export CODE_SERVER_SOURCE_ROOT=${RC_ROOT}/sagemaker/lifecycle/notebook-instance/cs

for profile in User Machine; do
    here=${CODE_SERVER_SOURCE_ROOT}/${profile}/settings.json
    there=${CODE_SERVER_SETTINGS_ROOT}/${profile}/settings.json
    if [[ ! -L ${there} || $(readlink -f ${there}) != $(readlink -f ${here}) ]]; then
        if [[ -f ${there} ]]; then
            mv ${there} ${there}.bak
            rm -f ${here}.bak
            ln -s ${there}.bak ${here}.bak
        else
            rm -f ${there}
        fi
        mkdir -p $(dirname ${there})
        ln -s ${here} ${there}
    fi
done

export SYNC_SETTINGS_SOURCE_ROOT=${CODE_SERVER_SOURCE_ROOT}/User/globalStorage/zokugun.sync-settings
export SYNC_SETTINGS_SETTINGS_ROOT=${CODE_SERVER_SETTINGS_ROOT}/User/globalStorage/zokugun.sync-settings
if [[ ! -d ${SYNC_SETTINGS_SETTINGS_ROOT} ]]; then
    ${CODE_SERVER} --install-extension zokugun.sync-settings
fi

rm -rf ${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml
cp ${SYNC_SETTINGS_SOURCE_ROOT}/settings-template.yml ${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml
rc_root_sed="$(echo ${RC_ROOT} | sed -E "s/([\\/\\.])/\\\\\1/g")"
sed -i -e "s/\${RC_ROOT}/${rc_root_sed}/g" ${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml

here=${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml
there=${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml
if [[ ! -L ${there} || $(readlink -f ${there}) != $(readlink -f ${here}) ]]; then
    if [[ -f ${there} ]]; then
        mv ${there} ${there}.bak
        rm -f ${here}.bak
        ln -s ${there}.bak ${here}.bak
    else
        rm -f ${there}
    fi
    mkdir -p $(dirname ${there})
    ln -s ${here} ${there}
fi

echo "Go back to Code Server, open Command Palette, and Run \"Sync Settings: Download (repository -> user)\"."