#!/bin/bash

set -e

# Follow https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-debian-8
# through step 7. This automates step 8, "Generate Certificates and Keys for Clients"

# usage:
# openvpn_easy_rsa_create_key.sh clientname

CA_FILE_NAME=/etc/openvpn/ca.crt
KEY_NAME="$1"

if [[ -n "${KEY_NAME}" ]] && \
   [[ -r "${CA_FILE_NAME}" ]] && \
   [[ -r "/etc/openvpn/easy-rsa/build-key-pass" ]] && \
   [[ -r "/etc/openvpn/server.conf" ]] && \
   [[ -r "/usr/share/doc/openvpn/examples/sample-config-files/client.conf" ]]; then

  # get protocol and port from server.conf
  OVPN_PROTO="$(grep -P "^proto\s+(\S+)" /etc/openvpn/server.conf | awk '{print $2}')"
  OVPN_PORT="$(grep -P "^port\s+\d+" /etc/openvpn/server.conf | awk '{print $2}')"

  # get external IP via curl ifconfig.io
  EXTERNAL_IP="$(curl -sSL ifconfig.io)"

  pushd /etc/openvpn/easy-rsa/

  # build-key-pass generates the client's key
  if ./build-key-pass "${KEY_NAME}"; then

    CRT_FILE_NAME=/etc/openvpn/easy-rsa/keys/"${KEY_NAME}".crt
    KEY_FILE_NAME=/etc/openvpn/easy-rsa/keys/"${KEY_NAME}".key
    if [[ -r "${CRT_FILE_NAME}" ]] && [[ -r "${KEY_FILE_NAME}" ]]; then

      # start with the sample client ovpn file and modify for this server and client key
      OVPN_FILE_NAME=/etc/openvpn/easy-rsa/keys/"${KEY_NAME}".ovpn
      cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf "${OVPN_FILE_NAME}"

      # adjust server settings
      sed -i "s/^\(proto \).*/\1${OVPN_PROTO}/" "${OVPN_FILE_NAME}"
      sed -i "s/^\(remote \).*/\1${EXTERNAL_IP} ${OVPN_PORT}/" "${OVPN_FILE_NAME}"
      sed -i "s/^\(tls-auth .*\)/;\1/" "${OVPN_FILE_NAME}"

      # append ca, crt, and key to client ovpn
      sed -i "s/^\(ca .*\)/;\1/" "${OVPN_FILE_NAME}"
      sed -i "s/^\(cert .*\)/;\1/" "${OVPN_FILE_NAME}"
      sed -i "s/^\(key .*\)/;\1/" "${OVPN_FILE_NAME}"
      echo '<ca>' >> "${OVPN_FILE_NAME}" && \
        cat "${CA_FILE_NAME}" >> "${OVPN_FILE_NAME}" && \
      echo '</ca>' >> "${OVPN_FILE_NAME}"
      echo '<cert>' >> "${OVPN_FILE_NAME}" && \
        cat "${CRT_FILE_NAME}" >> "${OVPN_FILE_NAME}" && \
      echo '</cert>' >> "${OVPN_FILE_NAME}"
      echo '<key>' >> "${OVPN_FILE_NAME}" && \
        cat "${KEY_FILE_NAME}" >> "${OVPN_FILE_NAME}" && \
      echo '</key>' >> "${OVPN_FILE_NAME}"

      popd
    else
      echo "${CRT_FILE_NAME} or ${KEY_FILE_NAME} do not exist after build-key-pass"
      popd
      exit 1
    fi
  else
    echo "./build-key-pass "${KEY_NAME}" failed"
    popd
    exit 1
  fi
else
  echo "necessary files and/or directories are missing"
  popd
  exit 1
fi
