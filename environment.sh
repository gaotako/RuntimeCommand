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

# Get CUDA version numbers.
getcu() {
    # CUDA release number start with "V".
    cu=$(nvcc --version | grep release | awk "{ print \$NF }")
    cuV=${cu:0:1}
    if [[ ${cuV} != "V" ]]; then
        #
        echo "error: CUDA release string is not \"V\${major}.\${minor}.\${release}\"."
        exit 1
    fi

    # Get major version.
    cu=${cu:1}
    cumajor=${cu%%.*}

    # Get minor version.
    cu=${cu#*.}
    cuminor=${cu%%.*}

    # Get release version.
    cu=${cu#*.}
    curelease=${cu%%.*}

    # CUDA release number should have and only have major, minor and release numbers.
    if [[ ${#cumajor} -gt 0 && ${#cuminor} -gt 0 && ${#curelease} -gt 0 && ${#cu} -eq ${#curelease} ]]; then
        #
        echo ${cumajor}${cuminor}
    else
        #
        echo "error: CUDA release string is not \"V\${major}.\${minor}.\${release}\"."
        exit 1
    fi
}

# Variables.
if [[ -z $(which nvcc 2>/dev/null) ]]; then
    #
    vercu=cpu
else
    #
    getcu
    vercu=cu${cumajor}${cuminor}
fi
verth=2.0.0

# Upgrade pip.
pip install --no-cache-dir --upgrade pip
pip install --no-cache-dir --upgrade setuptools
pip install --no-cache-dir --upgrade wheel

#
install black jupyter 23.7.0
install isort "" 5.12.0
install flake8 "" 6.1.0
install mypy "" 1.4.1
install pytest "" 7.4.0
install pytest-cov "" 4.1.0
install more-itertools "" 10.1.0
install numpy "" 1.24.4
install scipy "" 1.11.1
install scikit-learn "" 1.3.0
install matplotlib "" 3.7.2
install pandas "" 2.0.3
install seaborn "" 0.12.2
install lmdb "" 1.4.1
install ray "" 2.6.2
install numba "" 0.57.1
install textdistance extras 4.5.0
install datasketch "" 1.5.9
install tabulate "" 0.9.0

#
install torch "" ${verth} --extra-index-url https://download.pytorch.org/whl/${vercu}
install pyg_lib "" 0.2.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-scatter "" 2.1.1 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-sparse "" 0.6.17 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-cluster "" 1.6.1 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-spline-conv "" 1.2.2 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-geometric "" 2.3.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html

#
ignores["numpy"]=true
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
