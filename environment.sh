# Stop immediately on error.
set -e

# Decide acting stages according to arguments.
if [[ ${#} -eq 0 ]]; then
    # By default (no arguments), perform all stages.
    flag_install=1
    flag_outdate=1
    flag_unorder=0
    force_cumajor=
    force_cuminor=
else
    # With given arguments, only execute specified actions.
    flag_install=0
    flag_outdate=0
    flag_unorder=0
    force_cumajor=
    force_cuminor=
    while [[ ${#} -gt 0 ]]; do
        # Scan only acting stage arguments.
        case ${1} in
        install)
            # Act installation.
            flag_install=1
            ;;
        outdate)
            # Act outdate checking.
            flag_outdate=1
            ;;
        --unorder)
            # Disable order checking.
            flag_unorder=1
            ;;
        --cumajor)
            # Disable order checking.
            force_cumajor=${2}
            shift 1
            ;;
        --cuminor)
            # Disable order checking.
            force_cuminor=${2}
            shift 1
            ;;
        esac
        shift 1
    done
fi

# Global mappings:
# - Package levels defined in requirement;
# - Packages installed by this script and their versions;
# - Package installation order;
# - Packages with available latest update and their update versions;
# - Packages ignoring available latest update and ignoring reasons.
declare -A levels
declare -A installed
declare -a order
declare -A latests
declare -A ignores

# Load package order in requirement generated from previous installation.
# Then, we will start installation from bottom (0) level.
if [[ -f requirements.txt ]]; then
    # Collect every line in order text file.
    level=0
    while read line; do
        # Increase level per package line.
        package=${line%% *}
        levels[${package}]=${level}
        level=$((level + 1))
    done < requirements.txt
fi
toplevel=${level}

# Interface of using package installer for Python (pip) to install.
#
# Args
# ----
# - name
#   Python package index (PyPI) name of installing package.
# - extra
#   Extra dependency requirement names of installing package.
# - version
#   Version number of installing package.
# - args
#   Other arguments being directly passed to pip.
#
# Returns
# -------
install() {
    # Local variables for argument aliases.
    local package
    local version
    local extra

    # Parse arguments, and collect remaining arguments.
    package=${1}
    version=${2}
    extra=${3}
    shift 3

    # Ensure that installation order is correct.
    if [[ -z ${levels[${package}]} ]]; then
        # Use the maximum known level as default level for missing dependency.
        levels[${package}]=${toplevel}
    fi
    if [[ ${flag_unorder} -eq 0 && -n ${recent} && ${levels[${package}]} -lt ${level} ]]; then
        # Report improper installation order error.
        echo "error: package \"${package}\" is installed in the wrong order (${levels[${package}]}) after \"${recent}\" (${level})."
        exit 1
    fi
    recent=${package}
    level=${levels[${recent}]}

    # Perform installation command only when installation stage is active.
    if [[ ${flag_install} -gt 0 ]]; then
        # Extra dependency will influence the form of pip installation command.
        # Extra dependency only controls if some functionalities are supported, e.g., optimization, and has no influence to package version.
        # Different extra denpendencies will still be identified as the same package version.
        if [[ ${#extra} -eq 0 ]]; then
            # Default installation.
            pip install --no-cache-dir --upgrade ${package}==${version} ${*}
        else
            # Extra dependency installation.
            pip install --no-cache-dir --upgrade ${package}[${extra}]==${version} ${*}
        fi
    fi
    installed[${package}]=${version}
    order+=(${package})
}

# Parse package update information of package installer for Python (pip).
#
# Args
# ----
#
# Returns
# -------
outdate() {
    # Local variables for argument aliases.
    local lines
    local nlns
    local name
    local latest

    # Get pip update information.
    # Parse each information line.
    latests=()
    lines="$(pip list --outdated)"
    nlns=0
    while IFS= read -r line; do
        # Trace reading line number.
        # First and second line are headers to be ignored.
        nlns=$((nlns + 1))
        [[ ${nlns} -gt 2 ]] || continue

        # Get outdated package name and latest version.
        package=$(echo ${line} | awk "{print \$1}")
        latest=$(echo ${line} | awk "{print \$3}")
        latests[${package}]=${latest}
    done <<< "${lines}"
}

# Get CUDA version numbers.
#
# Args
# ----
#
# Returns
# -------
getcu() {
    # Local variables for processing CUDA version string.
    local cu
    local cuV
    local msg

    # CUDA release number start with "V".
    cu=$(nvcc --version | grep release | awk "{ print \$NF }")
    cuV=${cu:0:1}
    if [[ ${cuV} != "V" ]]; then
        # If the first character is not "V", directly stop this function with error raising.
        echo "error: CUDA release string is not \"V\${major}.\${minor}.\${release}\"."
        exit 1
    fi

    # Get major version.
    # Pay attention that `cumajor` is global.
    cu=${cu:1}
    cumajor=${cu%%.*}

    # Get minor version.
    # Pay attention that `cuminor` is global.
    cu=${cu#*.}
    cuminor=${cu%%.*}

    # Get release version.
    # Pay attention that `curelease` is global.
    cu=${cu#*.}
    curelease=${cu%%.*}

    # CUDA release number should have and only have major, minor and release numbers.
    if [[ ${#cumajor} -gt 0 && ${#cuminor} -gt 0 && ${#curelease} -gt 0 && ${#cu} -eq ${#curelease} ]]; then
        # Report major, minor and release versions.
        msg="Major = ${cumajor}, Minor = ${cuminor}, Release = ${curelease}"
        echo "Detect CUDA version numbers: ${msg}"
    else
        # If the version form is not as expected, directly stop this function with error raising.
        echo "error: CUDA release string is not \"V\${major}.\${minor}.\${release}\"."
        exit 1
    fi

    # Force to overwrite CUDA version numbers.
    if [[ -n ${force_cumajor} ]]; then
        # Overwrite major number.
        cumajor=${force_cumajor}
    fi
    if [[ -n ${force_cuminor} ]]; then
        # Overwrite minor number.
        cuminor=${force_cuminor}
    fi
}

# Package version related variables.
if [[ -z $(which nvcc 2>/dev/null) ]]; then
    # If GPU and CUDA are not active, use CPU as CUDA version for computation device.
    vercu=cpu
else
    # Otherwise, get CUDA version for computation device.
    getcu
    vercu=cu${cumajor}${cuminor}
fi
verth=2.2.0

# List all installation packages.
#
# Args
# ----
#
# Returns
# -------
listing() {
    # Install packages required for configuring environment following dependency and alphabet orders.
    install ipykernel 6.29.3 ""
    install ray 2.9.2 ""
    install torch ${verth} "" --index-url https://download.pytorch.org/whl/${vercu}
    install black 23.3.0 ""
    install flake8 7.0.0 ""
    install seaborn 0.13.2 ""
    install mypy 1.9.0 ""
    install numba 0.59.0 ""
    install pytest-cov 4.1.0 ""
    install requests-mock 1.11.0 ""
    install pytest-mock 3.12.0 ""
    install types-requests 2.31.0.20240218 ""
    install Cython 3.0.8 ""
    install isort 5.13.2 ""
    install lmdb 1.4.1 ""
    install more-itertools 10.2.0 ""
    install pip 24.0 ""
    install pipdeptree 2.16.1 ""
    install pybind11 2.11.1 ""
    install setuptools 69.2.0 ""
    install tabulate 0.9.0 ""
    install types-PyYAML 6.0.12.12 ""
    install wheel 0.43.0 ""
    install matplotlib 3.8.3 ""
    install ipython 8.22.2 ""
    install pandas 2.2.0 ""
    install requests 2.31.0 ""
    install scikit-learn 1.4.1.post1 ""
    install pytest 8.1.1 ""
    install PyYAML 6.0.1 ""
    install scipy 1.12.0 ""
    install numpy 1.26.4 ""
    #:||install ipykernel 6.29.3 ""
    #:||install ray 2.9.2 ""
    #:||install torch ${verth} "" --index-url https://download.pytorch.org/whl/${vercu}
    #:||install black 23.3.0 jupyter
    #:||install seaborn 0.13.2 ""
    #:||install flake8 7.0.0 ""
    #:||install numba 0.59.0 ""
    #:||install pytest-cov 4.1.0 ""
    #:||install mypy 1.9.0 ""
    #:||install requests-mock 1.11.0 ""
    #:||install types-requests 2.31.0.20240218 ""
    #:||install pytest-mock 3.12.0 ""
    #:||install isort 5.13.2 ""
    #:||install wheel 0.43.0 ""
    #:||install lmdb 1.4.1 ""
    #:||install Cython 3.0.8 ""
    #:||install tabulate 0.9.0 ""
    #:||install types-PyYAML 6.0.12.12 ""
    #:||install more-itertools 10.2.0 ""
    #:||install pip 24.0 ""
    #:||install pybind11 2.11.1 ""
    #:||install setuptools 69.2.0 ""
    #:||install pipdeptree 2.16.1 ""
    #:||install matplotlib 3.8.3 ""
    #:||install ipython 8.22.2 ""
    #:||install requests 2.31.0 ""
    #:||install scikit-learn 1.4.1.post1 ""
    #:||install pandas 2.2.0 ""
    #:||install pytest 8.1.1 ""
    #:||install PyYAML 6.0.1 ""
    #:||install scipy 1.12.0 ""
    #:||install numpy 1.26.4 ""
}

# Traverse all installing packages.
listing

# Colllect ordered dependency tree of current environment after installation.
echo "Build package dependency tree and order list."
mkdir -p .cache-python
pipdeptree --json-tree > .cache-python/dependencies.json
python src-python/pipord.py .cache-python
mv .cache-python/requirements.txt .

# Ensure customizaed installation is consistent with Python packaging system.
pip install -r requirements.txt
pipdeptree --json-tree > .cache-python/dependencies.json
python src-python/pipord.py .cache-python
if [[ $(cmp -s requirements.txt .cache-python/requirements.txt; echo ${?}) -ne 0 ]]; then
    # Report inconsistency issue.
    echo "Detect inconsistency of customized installation from Python packaging system."
    exit 1
fi

# Collect final version of isntallation involved in this script.
while read line; do
    # Each line is consisted by package name and installed version.
    package=${line%% *}
    version=${line##* }
    if [[ -n ${installed[${package}]} ]]; then
        # Report installed packages in collected order.
        echo ${package} ${version} >> .cache-python/.installations.txt
    fi
done < .cache-python/installations.txt
mv .cache-python/.installations.txt .cache-python/installations.txt

# Register update ignoring packages and reasons after installation listing.
ignores["ray"]="Ignore update other than major and minor."
ignores["torch"]="Ignore update other than major and minor."
ignores["black"]="Same as Brazil & Compatible with VSCode"
ignores["types-requests"]="Ignore update other than major and minor."
ignores["Cython"]="Ignore update other than major and minor."
ignores["types-PyYAML"]="Ignore update other than major and minor."
ignores["pandas"]="Ignore update other than major and minor."

# Outdate checking stage.
if [[ ${flag_outdate} -gt 0 ]]; then
    # Collect all outdated packages.
    echo "Sync package versions with cloud."
    outdate
    echo "There are ${#latests[@]} packages to be updated, and we only list those being involved in this setup:"

    # Traverse every packages installed by this script.
    for i in ${!order[@]}; do
        # Capture outdated ones among those packages.
        package=${order[${i}]}
        if [[ -n ${latests[${package}]} ]]; then
            # Outdate report varies according to ignoring settings.
            if [[ -z ${ignores[${package}]} ]]; then
                # If outdated package is not ignored, explicitly mark it as outdated.
                msg1="\x1b[1;93m${package}\x1b[0m"
                msg2="\x1b[2;94m${installed[${package}]}\x1b[0m"
                msg3="${msg1} (${msg2}) is \x1b[4;93moutdated\x1b[0m"
                msg4="latest version is \x1b[94m${latests[${package}]}\x1b[0m"
            else
                # Otherwise, report that it is forced to current version, and report reason.
                msg1="\x1b[92m${package}\x1b[0m"
                msg2="\x1b[94m${installed[${package}]}\x1b[0m"
                msg3="${msg1} (${msg2}) is \x1b[92mforced\x1b[0m for \"${ignores[${package}]}\""
                msg4="latest version is \x1b[2;94m${latests[${package}]}\x1b[0m"
            fi
            echo -e "${msg3} (${msg4})."
        fi
    done
fi