#!/bin/bash

set -e

if [[ -n $1 ]]; then
  OVPN_FILE="$1"
elif [[ -n "${OVPN_DEFAULT}" ]]; then
  OVPN_FILE="${OVPN_DEFAULT}"
else
  echo "Please specify .ovpn file"
  exit 1
fi

OPENVPN_PID_FILE="$(mktemp -u)"

function cleanup {
  if [[ -f "${OPENVPN_PID_FILE}" ]]; then
    OPENVPN_PID="$(head -n 1 "${OPENVPN_PID_FILE}")"
    if [[ -n $OPENVPN_PID ]]; then
      sudo kill -s TERM ${OPENVPN_PID}
    fi
    sudo rm -f "${OPENVPN_PID_FILE}"
  fi
}

OVPN_ORIG_NAME="$1"

if [[ -n "${OVPN_FILE}" ]] && [[ -f "${OVPN_FILE}" ]]; then
  trap "cleanup" EXIT

  sudo /usr/sbin/openvpn --config "${OVPN_FILE}" --writepid "${OPENVPN_PID_FILE}" --askpass --daemon

  transmission-daemon --foreground --config-dir "$HOME"/.config/transmission-daemon
fi
