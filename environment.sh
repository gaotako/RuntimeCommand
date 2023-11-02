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
        #
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
declare -A installed
declare -A latests
declare -A ignores

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
    done <<<"${lines}"
    nlns=$((nlns - 2))
    echo "${nlns} package(s) are outdated."
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
    if [[
        ${#cumajor} -gt 0 && ${#cuminor} -gt 0 && ${#curelease} -gt 0 &&
        ${#cu} -eq ${#curelease} ]] \
        ; then
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

# Installation stage.
if [[ ${flag_install} -gt 0 ]]; then
    # Upgrade pip.
    pip install --no-cache-dir --upgrade pip
    pip install --no-cache-dir --upgrade setuptools
    pip install --no-cache-dir --upgrade wheel
fi

# Install formatter packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install black jupyter 23.10.1
install flake8 "" 6.1.0
install isort "" 5.12.0

# Install static typing packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install mypy "" 1.6.1
install PyYAML "" 6.0.1
install types-requests "" 2.31.0.10
install types-PyYAML "" 6.0.12.12

# Install unittest packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install pytest "" 7.4.3
install pytest-cov "" 4.1.0
install pytest-mock "" 3.12.0

# Install basic extension packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install more-itertools "" 10.1.0
install requests "" 2.31.0
install requests-mock "" 1.11.0

# Install CPU numeric computation packages (level 1) regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install numpy "" 1.26.1

# Install CPU numeric computation packages (level 2) regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install scipy "" 1.11.3

# Install CPU numeric computation packages (level 3) regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install scikit-learn "" 1.3.2

# Install CPU numeric computation packages (level 4) regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install lmdb "" 1.4.1
install ray "" 2.7.1
install numba "" 0.58.1

# Install rendering packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install matplotlib "" 3.8.1

# Install database packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install pandas "" 2.1.2
install pyarrow "" 14.0.0

# Install database rendering packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install seaborn "" 0.13.0

# Install deep learning packages regardless of stage settings.
# Pseudo installation will be performed if installation stage is inactive.
install torch "" ${verth} --extra-index-url https://download.pytorch.org/whl/${vercu}
install pyg_lib "" 0.2.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-scatter "" 2.1.2 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-sparse "" 0.6.18 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-cluster "" 1.6.3 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-spline-conv "" 1.2.2 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html
install torch-geometric "" 2.4.0 -f https://data.pyg.org/whl/torch-${verth}+${vercu}.html

# Register update ignoring packages and reasons.
ignores["numpy"]="For Numba support."
ignores["torch"]="Use stable version."
ignores["torch-geometric"]="Use stable version."

# Outdate checking stage.
if [[ ${flag_outdate} -gt 0 ]]; then
    # Collect all outdated packages.
    outdate

    # Traverse every packages installed by this script.
    for package in ${!installed[@]}; do
        # Capture outdated ones among those packages.
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
