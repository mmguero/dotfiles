#!/bin/bash

###############################################################################
# force bash
if [ -z "$BASH_VERSION" ]; then
  echo "Wrong interpreter, please run \"$0\" with bash" >&2
  exit 1
fi

###############################################################################
# determine OS
unset MACOS
unset LINUX
unset WINDOWS
if [ $(uname -s) = 'Darwin' ]; then
  export MACOS=0
elif grep -q Microsoft /proc/version; then
  export WINDOWS=0
else
  export LINUX=0
fi

###############################################################################
# get directory script is executing from
[[ -n $MACOS ]] && REALPATH=grealpath || REALPATH=realpath
[[ -n $MACOS ]] && DIRNAME=gdirname || DIRNAME=dirname
if ! (type "$REALPATH" && type "$DIRNAME") > /dev/null; then
  echo "$(basename "${BASH_SOURCE[0]}") requires $REALPATH and $DIRNAME" >&2
  exit 1
fi
SCRIPT_PATH="$($DIRNAME $($REALPATH -e "${BASH_SOURCE[0]}") | head -n 1)"
FULL_PWD="$($REALPATH "$(pwd)" | head -n 1)"

###############################################################################
# script options
set -e
set -u
set -o pipefail
ENCODING="utf-8"

###############################################################################
# command-line parameters
# options
# -v        (verbose)
# -i input  (input string)

# parse command-line options
VERBOSE_FLAG=""
INPUT_STR=""
while getopts 'vi:' OPTION; do
  case "$OPTION" in
    v)
      VERBOSE_FLAG="-v"
      ;;

    i)
      INPUT_STR="$OPTARG"
      ;;

    ?)
      echo "script usage: $(basename $0) [-v] [-i input]" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

###############################################################################
# clean-up code
function clean_up {
  [[ -n $VERBOSE_FLAG ]] && echo "Cleaning up..." >&2
}

###############################################################################
# "main"
[[ -n $VERBOSE_FLAG ]] && echo "script in \"${SCRIPT_PATH}\" called from \"${FULL_PWD}\"" >&2 && set -x

trap clean_up EXIT

echo "Hello \""${INPUT_STR}"\"!"
