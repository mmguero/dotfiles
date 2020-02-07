#!/bin/bash

set -e

WORKDIR="$(mktemp -d)"

function cleanup {
  if [[ -d "${WORKDIR}" ]]; then
    find "${WORKDIR}"/ -type f -exec shred -u "{}" \;
    rmdir "${WORKDIR}"
  fi
}

OVPN_ORIG_NAME="$1"

if [[ -n "${OVPN_ORIG_NAME}" ]] && \
   [[ -f "${OVPN_ORIG_NAME}" ]]; then

  trap "cleanup" EXIT

  # extract private key from ovpn
  echo "Extracting the private key from ${OVPN_ORIG_NAME}"
  sed -n '/-----BEGIN.*PRIVATE KEY-----/,/-----END.*PRIVATE KEY-----/p' "${OVPN_ORIG_NAME}" > "${WORKDIR}"/extracted.key
  [[ -s "${WORKDIR}"/extracted.key ]] || (echo "could not extract private key from ovpn" ; exit 1)

  # check and/or decrypt the old key
  openssl rsa -in "${WORKDIR}"/extracted.key -check > "${WORKDIR}"/checked.key 2>&1 | grep -v --line-buffered "writing RSA key" || true
  [[ -s "${WORKDIR}"/checked.key ]] || (echo "could not validate private key" ; exit 1)

  # re-encrypt key
  echo "Re-encrypting private key with a new password"
  openssl rsa -aes256 -in "${WORKDIR}"/checked.key -out "${WORKDIR}"/new.key 2>&1 | grep -v --line-buffered "writing RSA key" || true
  [[ -s "${WORKDIR}"/new.key ]] || (echo "could not re-encrypt key" ; exit 1)

  # write out the new composite OVPN file
  TIMESTAMP=$(date +"%Y-%m-%d_%H:%M:%S")
  OVPN_NEW_NAME="${OVPN_ORIG_NAME%.*}_pwchg_${TIMESTAMP}.${OVPN_ORIG_NAME##*.}"
  echo "Writing new OVPN file \"${OVPN_NEW_NAME}\""
  sed -e '/-----BEGIN.*PRIVATE KEY-----/{:a; N; /\n-----END.*PRIVATE KEY-----$/!ba; r '"${WORKDIR}"/new.key -e 'd;}' "${OVPN_ORIG_NAME}" > "${OVPN_NEW_NAME}"

else
  echo "Please specify original .ovpn file as the single argument to this script"
  popd
  exit 1
fi
