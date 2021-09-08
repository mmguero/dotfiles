#!/usr/bin/env bash

set -euo pipefail
shopt -s nocasematch

function json_escape() {
  echo -n "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

RUN_PATH="$(pwd)"
[[ "$(uname -s)" = 'Darwin' ]] && REALPATH=grealpath || REALPATH=realpath
[[ "$(uname -s)" = 'Darwin' ]] && DIRNAME=gdirname || DIRNAME=dirname
if ! (type "$REALPATH" && type "$DIRNAME") > /dev/null; then
  echo "$(basename "${BASH_SOURCE[0]}") requires $REALPATH and $DIRNAME"
  exit 1
fi
SCRIPT_PATH="$($DIRNAME $($REALPATH -e "${BASH_SOURCE[0]}"))"

CERT_DIR=${SRV_CERT_DIR:-"$SCRIPT_PATH"}
KEY_BASE=${SRV_CERT_BASE:-"$(hostname -s)"}

CRT_NAME="$KEY_BASE.crt"
KEY_NAME="$KEY_BASE.key"
CA_NAME="ca.crt"

pushd "$CERT_DIR" >/dev/null 2>&1

if [[ -r "$CRT_NAME" ]] && [[ -r "$KEY_NAME" ]] && [[ -r "$CA_NAME" ]]; then

  DB_OUTPUT="$(sudo -n omv-confdbadm read "conf.system.certificate.ssl" | jq -r '.[] | "\(.uuid):\(.comment)"')"
  CERT_UUID="$(echo "$DB_OUTPUT" | cut -d: -f1)"
  OLD_CERT_COMMENT="$(echo "$DB_OUTPUT" | cut -d: -f2)"
  NEW_CERT_COMMENT="Updated by $(basename "$0") on $(date "+%Y-%m-%d %H:%M:%S")"

  CERTDATA="$(cat "$CERT_DIR"/"$CRT_NAME")"
  CERTDATA="$(json_escape "$CERTDATA")"

  KEYDATA="$(cat "$CERT_DIR"/"$KEY_NAME")"
  KEYDATA="$(json_escape "$KEYDATA")"

  # format and set key config
  CERTPARAMS={"\"uuid\":\"${CERT_UUID}\", \"certificate\":${CERTDATA}, \"privatekey\":${KEYDATA}, \"comment\":\"${NEW_CERT_COMMENT}\""}
  sudo -n omv-rpc "CertificateMgmt" "set" "${CERTPARAMS}"

  # apply configuration changes
  sudo -n omv-rpc "Config" "applyChanges" "{\"modules\":[\"certificates\"],\"force\":false}"
  sudo -n omv-rpc "Config" "applyChanges" "{\"modules\":$(cat /var/lib/openmediavault/dirtymodules.json),\"force\":true}"
  sudo /bin/systemctl reload nginx

  # restart some docker stuff specific to this box
  # set +e
  #for SERVICEDIR in /home/tlacuache/services/piwigo; do
  #  pushd "$SERVICEDIR" >/dev/null 2>&1
  #  docker-compose down
  #  docker-compose up -d
  #  popd >/dev/null 2>&1
  #done
  # set -e

  exit 0
else
  echo "Unable to read CA, certificate and key files" >&2
  exit 1
fi
