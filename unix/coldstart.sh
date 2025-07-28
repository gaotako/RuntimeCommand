cish=$(ps -o comm -p $$ | tail -1 | cut -d " " -f 1)

case ${cish} in
*bash*)
    shdir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
    ;;
*zsh*)
    shdir=${0:a:h}
    ;;
*sh*)
    shdir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
    ;;
*)
    echo -e "Detect UNKNOWN Current Interactive Shell (cish): \"${cish}\", thus this script directory can not be detected."
    return 1 2>/dev/null || exit 1
    ;;
esac

source ${shdir}/rc.sh -C
