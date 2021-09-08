#!/usr/bin/env bash

# requires that openldap image be built with UID/GID so that the runtime
# user has permissions to the cert files. also, for now the user needs to
# be able to run sudo without prompt (todo)

set -e

CERTS_DIR="certs"
CRT_NAME="openldap.crt"
KEY_NAME="openldap.key"
CA_NAME="ca.crt"

LDAP_CERTS_DIR="certs_ldap"
LDAP_CRT_NAME="ldap.crt"
LDAP_KEY_NAME="ldap.key"
LDAP_CA_NAME="ca.crt"

WEB_CERTS_DIR="certs_web"
WEB_CRT_NAME="phpldapadmin.crt"
WEB_KEY_NAME="phpldapadmin.key"
WEB_CA_NAME="ca.crt"

EXPORT_LDIF_NAME="export.ldif"
EXPORT_WAIT_SECS=60
LDAP_ADMIN_CN="cn=admin,dc=local,dc=lan"
LDAP_ADMIN_URL="ldap://localhost:389"

# force-navigate to Malcolm base directory (parent of scripts/ directory)
RUN_PATH="$(pwd)"
[[ "$(uname -s)" = 'Darwin' ]] && REALPATH=grealpath || REALPATH=realpath
[[ "$(uname -s)" = 'Darwin' ]] && DIRNAME=gdirname || DIRNAME=dirname
if ! (type "$REALPATH" && type "$DIRNAME" && type ldapadd) > /dev/null; then
  echo "$(basename "${BASH_SOURCE[0]}") requires $REALPATH, $DIRNAME and ldapadd"
  exit 1
fi
SCRIPT_PATH="$($DIRNAME $($REALPATH -e "${BASH_SOURCE[0]}"))"
pushd "$SCRIPT_PATH" >/dev/null 2>&1

docker-compose down || true

pushd ./"$LDAP_CERTS_DIR" >/dev/null 2>&1
cp ../"$CERTS_DIR"/"$CA_NAME" ./"$LDAP_CA_NAME"
cp ../"$CERTS_DIR"/"$CRT_NAME" ./"$LDAP_CRT_NAME"
cp ../"$CERTS_DIR"/"$KEY_NAME" ./"$LDAP_KEY_NAME"
popd >/dev/null 2>&1

pushd ./"$WEB_CERTS_DIR" >/dev/null 2>&1
sudo cp ../"$CERTS_DIR"/"$CA_NAME" ./"$WEB_CA_NAME"
sudo cp ../"$CERTS_DIR"/"$CRT_NAME" ./"$WEB_CRT_NAME"
sudo cp ../"$CERTS_DIR"/"$KEY_NAME" ./"$WEB_KEY_NAME"
popd >/dev/null 2>&1

docker-compose up -d

if [[ -r "$EXPORT_LDIF_NAME" ]]; then
  sleep $EXPORT_WAIT_SECS
  ldapadd -x -D "$LDAP_ADMIN_CN" -w "$(grep LDAP_ADMIN_PASSWORD docker-compose.yml | sed "s/.*[[:space:]]*=[[:space:]]*//")" -H "$LDAP_ADMIN_URL" -f "$EXPORT_LDIF_NAME"
fi


