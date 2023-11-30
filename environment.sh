# Stop immediately on error.
set -e

# Decide acting stages according to arguments.
if [[ ${#} -eq 0 ]]; then
    # By default (no arguments), perform all stages.
    flag_install=1
    flag_outdate=1
else
    # With given arguments, only execute specified actions.
    flag_install=0
    flag_outdate=0
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
        esac
        shift 1
    done
fi

# Global mappings:
# - Packages installed by this script and their versions;
# - Packages with available latest update and their update versions;
# - Packages ignoring available latest update and ignoring reasons.
declare -A levels
declare -A installed
declare -a history
declare -A latests
declare -A ignores

# Load package order of reversed dependency generated from previous installation.
# Then, we will start installation from bottom (0) level.
if [[ -f orders.txt ]]; then
    # Collect every line in order text file.
    toplevel=0
    while read line; do
        # Each line is consisted by order level and package name.
        name=${line##* }
        level=${line%% *}
        levels[${name}]=${level}

        # Update maximum level.
        if [[ ${level} -gt ${toplevel} ]]; then
            # Overwrite top value.
            toplevel=${level}
        fi
    done < orders.txt
fi
level=0
toplevel=$((toplevel + 1))

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
    local name
    local extra
    local version

    # Parse arguments, and collect remaining arguments.
    name=${1}
    extra=${2}
    version=${3}
    shift 3

    # Ensure that installation order is correct.
    if [[ -z ${levels[${name}]} ]]; then
        # Use the maximum known level as default level for missing dependency.
        levels[${name}]=${toplevel}
    fi
    if [[ ${levels[${name}]} -lt ${level} ]]; then
        # Report improper installation order error.
        echo "error: package \"${name}\" is installed in the wrong order (${levels[${name}]} after ${level})."
        exit 1
    fi
    level=${levels[${name}]}

    # Perform installation command only when installation stage is active.
    if [[ ${flag_install} -gt 0 ]]; then
        # Extra dependency will influence the form of pip installation command.
        # Extra dependency only controls if some functionalities are supported, e.g., optimization, and has no influence to package version.
        # Different extra denpendencies will still be identified as the same package version.
        if [[ ${#extra} -eq 0 ]]; then
            # Default installation.
            pip install --no-cache-dir --upgrade ${name}==${version} ${*}
        else
            # Extra dependency installation.
            pip install --no-cache-dir --upgrade ${name}[${extra}]==${version} ${*}
        fi
    fi
    installed[${name}]=${version}
    history+=(${name})
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
        name=$(echo ${line} | awk "{print \$1}")
        latest=$(echo ${line} | awk "{print \$3}")
        latests[${name}]=${latest}
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
verth=2.1.0

# List all installation packages.
#
# Args
# ----
#
# Returns
# -------
listing() {
    # Install packages required for configuring environment following dependency and alphabet orders.
    install isort "" 5.12.0
    install lmdb "" 1.4.1
    install more-itertools "" 10.1.0
    install numpy "" 1.26.2
    install pip "" 23.3.1
    install pipdeptree "" 2.13.1
    install pyg-lib "" 0.2.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
    install PyYAML "" 6.0.1
    install setuptools "" 69.0.2
    install torch-scatter "" 2.1.2 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
    install torch-spline-conv "" 1.2.2 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
    install types-PyYAML "" 6.0.12.12
    install wheel "" 0.42.0
    install black jupyter 23.11.0
    install flake8 "" 6.1.0
    install mypy "" 1.7.1
    install numba "" 0.58.1
    install pyarrow "" 14.0.1
    install pytest "" 7.4.3
    install requests "" 2.31.0
    install scipy "" 1.11.4
    install types-requests "" 2.31.0.10
    install matplotlib "" 3.8.2
    install pandas "" 2.1.3
    install pytest-cov "" 4.1.0
    install pytest-mock "" 3.12.0
    install requests-mock "" 1.11.0
    install scikit-learn "" 1.3.2
    install torch "" ${verth} --index-url https://download.pytorch.org/whl/${vercu}
    install torch-cluster "" 1.6.3 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
    install torch-sparse "" 0.6.18 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
    install ipython "" 8.18.1
    install seaborn "" 0.13.0
    install torch-geometric "" 2.4.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
    install ray "" 2.8.0
}

# Register update ignoring packages and reasons after installation listing.
listing
ignores["torch"]="Ignore release level update."

# Outdate checking stage.
if [[ ${flag_outdate} -gt 0 ]]; then
    # Collect all outdated packages.
    echo "Sync package versions with cloud."
    outdate
    echo "There are ${#latests[@]} packages to be updated, and we only list those being involved in this setup:"

    # Traverse every packages installed by this script.
    for i in ${!history[@]}; do
        # Capture outdated ones among those packages.
        package=${history[${i}]}
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

# Colllect dependency tree of current environment after installation.
echo "Build package dependency tree and order list."
pipdeptree --json-tree > dependencies.json
python pkgsort.py dependencies.json > orders.txt