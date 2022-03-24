#!/usr/bin/env bash

###############################################################################
# force bash
if [ -z "$BASH_VERSION" ]; then
  echo "Wrong interpreter, please run \"$0\" with bash" >&2
  exit 1
fi

###############################################################################
# determine OS, root user and some other parameters
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

#
if [[ $EUID -eq 0 ]]; then
  SCRIPT_USER="root"
  SUDO_CMD=""
else
  SCRIPT_USER="$(whoami)"
  SUDO_CMD="sudo"
fi

# set BASH_NONINTERACTIVE=1 to accept defaults without interaction
BASH_NONINTERACTIVE=${BASH_NONINTERACTIVE:-0}

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

###################################################################################
# _GetConfirmation - get a yes/no confirmation from the user (or accept the default)
function _GetConfirmation {
  PROMPT=${1:-"[y/N]?"}
  DEFAULT_ANSWER=${2:-n}
  unset CONFIRMATION
  if (( $BASH_NONINTERACTIVE == 1 )); then
    echo "${PROMPT} ${DEFAULT_ANSWER}" >&2
  else
    echo -n "${PROMPT} " >&2
    read CONFIRMATION
  fi
  CONFIRMATION=${CONFIRMATION:-$DEFAULT_ANSWER}
  echo $CONFIRMATION
}

###################################################################################
# _GetString - get a string response from the user (or accept the default)
function _GetString {
  PROMPT=${1:-""}
  DEFAULT_ANSWER=${2:-""}
  unset RESPONSE
  if (( $BASH_NONINTERACTIVE == 1 )); then
    echo "${PROMPT} ${DEFAULT_ANSWER}" >&2
  else
    echo -n "${PROMPT} " >&2
    read RESPONSE
  fi
  RESPONSE=${RESPONSE:-$DEFAULT_ANSWER}
  echo $RESPONSE
}

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
INPUT_STR="world"
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
function _clean_up {
  [[ -n $VERBOSE_FLAG ]] && echo "Cleaning up..." >&2
}

###############################################################################
# hello world
function HelloWorld() {
  echo "Hello, ${INPUT_STR}!"
}

################################################################################
# "main" - ask the user what they want to do, and do it (or do it without interaction)
[[ -n $VERBOSE_FLAG ]] && echo "script in \"${SCRIPT_PATH}\" called from \"${FULL_PWD}\"" >&2 && set -x

trap _clean_up EXIT

# get a list of all the "public" functions (not starting with _)
FUNCTIONS=($(declare -F | awk '{print $NF}' | sort | egrep -v "^_"))

# present the menu to our customer and get their selection
printf "%s\t%s\n" "0" "ALL"
for i in "${!FUNCTIONS[@]}"; do
  ((IPLUS=i+1))
  printf "%s\t%s\n" "$IPLUS" "${FUNCTIONS[$i]}"
done

if (( $BASH_NONINTERACTIVE == 1 )); then
  echo "Operation: ALL (non-interactive)"
  USER_FUNCTION_IDX=0
else
  echo -n "Operation:"
  read USER_FUNCTION_IDX
fi

if (( $USER_FUNCTION_IDX == 0 )); then
  # ALL: do everything, in order
  HelloWorld

elif (( $USER_FUNCTION_IDX > 0 )) && (( $USER_FUNCTION_IDX <= "${#FUNCTIONS[@]}" )); then
  # execute one function, à la carte
  USER_FUNCTION="${FUNCTIONS[((USER_FUNCTION_IDX-1))]}"
  echo $USER_FUNCTION
  $USER_FUNCTION

else
  # some people just want to watch the world burn
  echo "Invalid operation selected" >&2
  exit 1;
fi
