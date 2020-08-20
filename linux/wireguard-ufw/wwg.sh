#!/usr/bin/env bash

validate_operation() {
    grep -F -q -x "$1" <<EOF
start
stop
status
show
EOF
}

if (( $# >= 2 )) && validate_operation "$1" ; then
  if [[ "$1" == "show" ]]; then
    wg show "$2"
  else
    systemctl "$1" wg-quick@"$2".service
  fi
else
  echo "Usage:"
  echo -e "\t$(basename $(test -L "$0" && readlink "$0" || echo "$0")) [start|stop|status|show] [interface]"
fi
