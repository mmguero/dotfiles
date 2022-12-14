#!/usr/bin/env bash

RAW_IP="$1"
SLEEP="${2:-15}"
KILLPROG="${3:-deluge-gtk}"
KILLSIG="${4:-TERM}"

COMMANDS=("curl -sSL ifconfig.me/ip" "curl -sSL ifconfig.co/" "curl -sSL icanhazip.com" "curl -sSL ipinfo.io/ip" "curl -sSL ifconfig.io/ip")

BREAKER=0
while (( $BREAKER == 0 )); do
    for CMD in "${COMMANDS[@]}"; do
        CURRENT_IP="$(${CMD})"
        if [[ "${CURRENT_IP}" == "${RAW_IP}" ]]; then
            BREAKER=1
            break
        else
            echo "${CURRENT_IP} (via \"${CMD}\")"
            sleep "${SLEEP}"
        fi
    done
done

echo "${RAW_IP}"
killall -s $KILLSIG "$KILLPROG"
