# Stop immediately on error.
set -e

# Decide sagemaker information according to arguments.
if [[ ${#} -eq 1 ]]; then
    # Parse environment name.
    name=${1}
else
    # Report error.
    echo -e "error: environment name must be provided in arguments."
    exit 1
fi

# Register given virtual environment to sagemaker.
python -m ipykernel install --user --name ${name} --display-name ${name}