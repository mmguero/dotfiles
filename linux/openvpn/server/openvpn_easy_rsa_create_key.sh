#!/bin/bash

set -e

# Follow https://www.golinuxcloud.com/install-openvpn-server-easy-rsa-3-centos-7/
# for server setup. This automates client key setup "Generate Certificates and Keys for Clients"

# usage:
# openvpn_easy_rsa_create_key.sh clientname

CA_FILE_NAME=/etc/openvpn/keys/ca.crt
KEY_NAME="$1"

if [[ -n "${KEY_NAME}" ]] && \
   [[ -r "${CA_FILE_NAME}" ]] && \
   [[ -r "/etc/openvpn/easy-rsa/easyrsa" ]] && \
   [[ -r "/etc/openvpn/server.conf" ]] && \
   [[ -r "/usr/share/doc/openvpn/examples/sample-config-files/client.conf" ]]; then

  # get protocol and port from server.conf
  OVPN_PROTO="$(grep -P "^proto\s+(\S+)" /etc/openvpn/server.conf | awk '{print $2}')"
  OVPN_PORT="$(grep -P "^port\s+\d+" /etc/openvpn/server.conf | awk '{print $2}')"

  # get external IP via curl ifconfig.io
  EXTERNAL_IP="$(curl -sSL ifconfig.io)"

  pushd /etc/openvpn/easy-rsa/

  # build-key-pass generates the client's key
  if ./easyrsa gen-req "${KEY_NAME}"; then

    REQ_FILE_NAME=/etc/openvpn/easy-rsa/pki/reqs/"${KEY_NAME}".req
    KEY_FILE_NAME=/etc/openvpn/easy-rsa/pki/private/"${KEY_NAME}".key
    if [[ -r "${REQ_FILE_NAME}" ]] && [[ -r "${KEY_FILE_NAME}" ]] && ./easyrsa sign client "${KEY_NAME}"; then
      CRT_FILE_NAME=/etc/openvpn/easy-rsa/pki/issued/"${KEY_NAME}".crt
      if [[ -r "${CRT_FILE_NAME}" ]]; then

        # copy keys to openvpn
        cp -va "${CRT_FILE_NAME}" /etc/openvpn/keys/
        cp -va "${KEY_FILE_NAME}" /etc/openvpn/keys/

        # start with the sample client ovpn file and modify for this server and client key
        OVPN_FILE_NAME=/etc/openvpn/keys/"${KEY_NAME}".ovpn
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
          sed -ne '/----BEGIN/,$ p' "${CA_FILE_NAME}" >> "${OVPN_FILE_NAME}" && \
        echo '</ca>' >> "${OVPN_FILE_NAME}"
        echo '<cert>' >> "${OVPN_FILE_NAME}" && \
          sed -ne '/----BEGIN/,$ p' "${CRT_FILE_NAME}" >> "${OVPN_FILE_NAME}" && \
        echo '</cert>' >> "${OVPN_FILE_NAME}"
        echo '<key>' >> "${OVPN_FILE_NAME}" && \
          sed -ne '/----BEGIN/,$ p' "${KEY_FILE_NAME}" >> "${OVPN_FILE_NAME}" && \
        echo '</key>' >> "${OVPN_FILE_NAME}"

        popd

      else
        echo "${CRT_FILE_NAME} does not exist after sign client"
        popd
        exit 1
      fi
    else
      echo "${REQ_FILE_NAME} or ${KEY_FILE_NAME} do not exist after gen-req, or sign client failed"
      popd
      exit 1
    fi
  else
    echo "./easyrsa gen-req "${KEY_NAME}" failed"
    popd
    exit 1
  fi
else
  echo "necessary files and/or directories are missing"
  popd
  exit 1
fi
