set -eux

if [[ -z ${RC_ROOT} ]]; then
    echo "Code Server coldstart requires RuntimeCommand (\"${RC_ROOT}\") to be initialized."
    exit 1
fi

CS_SOURCE_ROOT=${RC_ROOT}/sagemaker/lifecycle/notebook-instance/cs
CS_SETTINGS_ROOT=${XDG_DATA_HOME}/code-server

SYNC_SETTINGS_SOURCE_ROOT=${CS_SOURCE_ROOT}/User/globalStorage/zokugun.sync-settings
SYNC_SETTINGS_SETTINGS_ROOT=${CS_SETTINGS_ROOT}/User/globalStorage/zokugun.sync-settings

if [[ ! -d ${SYNC_SETTINGS_SETTINGS_ROOT} ]]; then
    echo "Code Server coldstart requires \"Sync Settings\" extension to be manually installed first."
    exit 1
fi

for profile in User Machine; do
    if [[ ! -L ${CS_SETTINGS_ROOT}/${profile}/settings.json || $(readlink -f ${CS_SETTINGS_ROOT}/${profile}/settings.json) != ${CS_SOURCE_ROOT}/${profile}/settings.json ]]; then
        if [[ -f ${CS_SETTINGS_ROOT}/${profile}/settings.json ]]; then
            mv ${CS_SETTINGS_ROOT}/${profile}/settings.json ${CS_SETTINGS_ROOT}/${profile}/settings.json.bak
        else
            rm -f ${CS_SETTINGS_ROOT}/${profile}/settings.json
        fi
        mkdir -p ${CS_SETTINGS_ROOT}/${profile}
        ln -s ${CS_SOURCE_ROOT}/${profile}/settings.json ${CS_SETTINGS_ROOT}/${profile}/settings.json
    fi
done

if [[ ! -L ${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml || $(readlink -f ${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml) != ${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml ]]; then
    if [[ -f ${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml ]]; then
        mv ${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml ${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml.bak
    else
        rm -f ${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml
    fi
    mkdir -p ${SYNC_SETTINGS_SETTINGS_ROOT}
    ln -s ${SYNC_SETTINGS_SOURCE_ROOT}/settings.yml ${SYNC_SETTINGS_SETTINGS_ROOT}/settings.yml
fi

echo "Go back to Code Server, open Command Palette, and Run \"Sync Settings: Download (repository -> user)\"."