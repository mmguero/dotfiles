#!/usr/bin/env bash

# change/set the password of a PEM file

# https://gist.github.com/mmguero/6f576e45266ff370732dd7b1e2bf9777

set -e

WORKDIR="$(mktemp -d)"

function cleanup {
  if [[ -d "${WORKDIR}" ]]; then
    find "${WORKDIR}"/ -type f -exec shred -u "{}" \;
    rmdir "${WORKDIR}"
  fi
}

FILE_ORIG_NAME="$1"

if [[ -n "${FILE_ORIG_NAME}" ]] && \
   [[ -f "${FILE_ORIG_NAME}" ]]; then

  trap "cleanup" EXIT

  # extract private key from file
  echo "Extracting the private key from ${FILE_ORIG_NAME}"
  sed -n '/-----BEGIN.*PRIVATE KEY-----/,/-----END.*PRIVATE KEY-----/p' "${FILE_ORIG_NAME}" > "${WORKDIR}"/extracted.key
  [[ -s "${WORKDIR}"/extracted.key ]] || (echo "could not extract private key from file" ; exit 1)

  # check and/or decrypt the old key
  openssl rsa -in "${WORKDIR}"/extracted.key -check > "${WORKDIR}"/checked.key 2>&1 | grep -v --line-buffered "writing RSA key" || true
  [[ -s "${WORKDIR}"/checked.key ]] || (echo "could not validate private key" ; exit 1)

  # re-encrypt key
  echo "Re-encrypting private key with a new password"
  openssl rsa -aes256 -in "${WORKDIR}"/checked.key -out "${WORKDIR}"/new.key 2>&1 | grep -v --line-buffered "writing RSA key" || true
  [[ -s "${WORKDIR}"/new.key ]] || (echo "could not re-encrypt key" ; exit 1)

  # write out the new composite OVPN file
  TIMESTAMP=$(date +"%Y-%m-%d_%H:%M:%S")
  FILE_NEW_NAME="${FILE_ORIG_NAME%.*}_pwchg_${TIMESTAMP}.${FILE_ORIG_NAME##*.}"
  echo "Writing new OVPN file \"${FILE_NEW_NAME}\""
  sed -e '/-----BEGIN.*PRIVATE KEY-----/{:a; N; /\n-----END.*PRIVATE KEY-----$/!ba; r '"${WORKDIR}"/new.key -e 'd;}' "${FILE_ORIG_NAME}" > "${FILE_NEW_NAME}"

else
  echo "Please specify original file as the single argument to this script"
  popd
  exit 1
fi
