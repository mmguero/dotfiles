#!/bin/bash

set -e

if [[ -n $1 ]]; then
  WG_IFACE="$1"
elif [[ -n "${WG_IFACE_DEFAULT}" ]]; then
  WG_IFACE="${WG_IFACE_DEFAULT}"
else
  echo "Please specify WireGuard interface (eg., wg2)"
  exit 1
fi

function cleanup {
  sudo systemctl stop wg-quick@"${WG_IFACE}"
}

if [[ -n "${WG_IFACE}" ]]; then
  trap "cleanup" EXIT

  sudo systemctl start wg-quick@"${WG_IFACE}"

  transmission-daemon --foreground --config-dir "$HOME"/.config/transmission-daemon
fi
