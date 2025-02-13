CS_SOURCE_ROOT=${RC_ROOT}/sagemaker/lifecycle/notebook-instance/cs
CS_SETTINGS_ROOT=${XDG_DATA_HOME}/code-server/User
SYNC_SETTINGS_ROOT=${CS_SETTINGS_ROOT}/globalStorage/zokugun.sync-settings

if [[ ! -d ${SYNC_SETTINGS_ROOT} ]]; then
    echo "Code Server coldstart requires \"Sync Settings\" extension to be manually installed first."
    exit 0
fi

if [[ ! -L ${CS_SETTINGS_ROOT}/settings.json || $(readlink -f ${CS_SETTINGS_ROOT}/settings.json) != ${CS_SOURCE_ROOT}/settings.json ]]; then
    if [[ -f ${CS_SETTINGS_ROOT}/settings.json ]]; then
        mv ${CS_SETTINGS_ROOT}/settings.json ${CS_SETTINGS_ROOT}/settings.json.bak
    else
        rm -f ${CS_SETTINGS_ROOT}/settings.json
    fi
    mkdir -p ${XDG_DATA_HOME}/code-server/User
    ln -s ${CS_SOURCE_ROOT}/settings.json ${CS_SETTINGS_ROOT}/settings.json
fi

if [[ ! -L ${SYNC_SETTINGS_ROOT}/settings.yml || $(readlink -f ${SYNC_SETTINGS_ROOT}/settings.yml) != ${CS_SOURCE_ROOT}/sync_settings.yml ]]; then
    if [[ -f ${SYNC_SETTINGS_ROOT}/settings.yml ]]; then
        mv ${SYNC_SETTINGS_ROOT}/settings.yml ${SYNC_SETTINGS_ROOT}/settings.yml.bak
    else
        rm -f ${SYNC_SETTINGS_ROOT}/settings.yml
    fi
    mkdir -p ${XDG_DATA_HOME}/code-server/User/globalStorage/zokugun.sync-settings
    ln -s ${CS_SOURCE_ROOT}/sync_settings.yml ${SYNC_SETTINGS_ROOT}/settings.yml
fi
