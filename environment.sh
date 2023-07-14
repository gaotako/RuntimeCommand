#
set -e

#
declare -A installed
declare -A latests
declare -A ignores

# Using package installer for Python to maintain.
install() {
    #
    local name
    local extra
    local version

    #
    name=${1}
    extra=${2}
    version=${3}
    shift 3

    #
    if [[ ${#extra} -eq 0 ]]; then
        #
        pip install --no-cache-dir --upgrade ${name}==${version} ${*}
    else
        #
        pip install --no-cache-dir --upgrade ${name}[${extra}]==${version} ${*}
    fi
    installed[${name}]=${version}
}

#
outdate() {
    #
    local nlns
    local name
    local latest

    #
    latests=()
    nlns=0
    while IFS= read -r line; do
        #
        nlns=$((nlns + 1))
        [[ ${nlns} -gt 2 ]] || continue

        #
        name=$(echo ${line} | awk "{print \$1}")
        latest=$(echo ${line} | awk "{print \$3}")
        latests[${name}]=${latest}
    done <<<$(pip list --outdated)
}

# Variables.
if [[ -z $(which nvcc) ]]; then
    #
    vercu=cpu
else
    #
    vercu=cu117
fi
verth=2.0.0

#
install black "" 23.7.0
install mypy "" 1.4.1
install pytest "" 7.4.0
install pytest-cov "" 4.1.0
install more_itertools "" 8.14.0
install numpy "" 1.25.1
install scipy "" 1.11.1
install scikit-learn "" 1.3.0
install matplotlib "" 3.7.2
install pandas "" 2.0.3
install seaborn "" 0.12.2
install lmdb "" 1.4.1
install torch "" ${verth} --extra-index-url https://download.pytorch.org/whl/${vercu}
install pyg_lib "" 0.2.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-scatter "" 2.1.1 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-sparse "" 0.6.17 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-cluster "" 1.6.1 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-spline-conv "" 1.2.2 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-geometric "" 2.3.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html

#
ignores["torch"]=true
ignores["torch-geometric"]=true

#
outdate
for package in ${!installed[@]}; do
    #
    if [[ -n ${latests[${package}]} ]]; then
        #
        if [[ -z ${ignores[${package}]} ]]; then
            # If outdated package is not ignored, explicitly mark it is outdated.
            msg1="\x1b[1;93m${package}\x1b[0m"
            msg2="\x1b[2;94m${installed[${package}]}\x1b[0m"
            msg3="${msg1} (${msg2}) is \x1b[4;93moutdated\x1b[0m"
            msg4="latest version is \x1b[94m${latests[${package}]}\x1b[0m"
        else
            # Otherwise, report that it is forced to current version.
            msg1="\x1b[92m${package}\x1b[0m"
            msg2="\x1b[94m${installed[${package}]}\x1b[0m"
            msg3="${msg1} (${msg2}) is \x1b[92mforced\x1b[0m"
            msg4="latest version is \x1b[2;94m${latests[${package}]}\x1b[0m"
        fi
        echo -e "${msg3} (${msg4})."
    fi
done
