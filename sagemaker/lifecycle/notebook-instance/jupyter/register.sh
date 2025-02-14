if [[ $# -ge 1 ]]; then
    NAME=${1}
    shift 1
else
    NAME="Project"
fi
if [[ $# -ge 1 ]]; then
    DISPLAY_NAME=${1}
    shift 1
else
    DISPLAY_NAME=${NAME}
fi

python -m ipykernel install --user --name ${NAME} --display-name ${DISPLAY_NAME}