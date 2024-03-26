# Stop immediately on error.
set -e

# Clean runtime commands.
for rcfile in "${HOME}/.bash_profile" "${HOME}/.bashrc" "${HOME}/.profile"; do
    # Only proceed for existing runtime commands.
    if [[ -f ${rcfile} ]]; then
        # Make a backup of system runtime commands.
        mv ${rcfile} ${rcfile}.backup
    fi
    rm -f ${rcfile}
done

# Use SageMaker specific runtime command initialization.
ln -s ${HOME}/SageMaker/RuntimeCommand/sagemaker/profile.sh ${HOME}/.bash_profile
cp -s ${HOME}/SageMaker/RuntimeCommand/sagemaker/bashrc.sh ${HOME}/SageMaker/bashrc.sh
ln -s ${HOME}/SageMaker/bashrc.sh ${HOME}/.bashrc
ln -s ${HOME}/.bash_profile ${HOME}/.profile