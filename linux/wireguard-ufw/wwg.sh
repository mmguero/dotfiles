#!/usr/bin/env bash

CONFIG_DIR=${WIREGUARD_CONFIG_DIR:-"/etc/wireguard"}
IFACE_REPLACER=XXX

OPERATION="$1"
INTERFACE="$2"
CONFIG_FILE="$CONFIG_DIR/$INTERFACE.conf"
CONFIG_FILE_RESTORE=
FINAL_EXIT_CODE=

WG_OPERATIONS=(
  "dec;;;"
  "down;wg-quick;down;$IFACE_REPLACER"
  "enc;;;"
  "show;wg;show;$IFACE_REPLACER"
  "start;systemctl;start;wg-quick@$IFACE_REPLACER.service"
  "status;systemctl;status;wg-quick@$IFACE_REPLACER.service"
  "enable;systemctl;enable;wg-quick@$IFACE_REPLACER.service"
  "disable;systemctl;disable;wg-quick@$IFACE_REPLACER.service"
  "stop;systemctl;stop;wg-quick@$IFACE_REPLACER.service"
  "up;wg-quick;up;$IFACE_REPLACER"
)
for i in ${FILES_IN_IMAGES[@]}; do
  FILE="$(echo "$i" | cut -d';' -f1)"
  IMAGE="$(echo "$i" | cut -d';' -f2)"
  (( "$(filesize_in_image $IMAGE "$FILE")" > 0 )) || { echo "Failed to create \"$FILE\" in \"$IMAGE\""; exit 1; }
done

function encrypt_file() {
  DECFILE="$1"
  ENCFILE="$2"
  ( [[ -n $DECFILE ]] && \
    [[ -r "$DECFILE" ]] && \
    openssl enc -base64 -aes-256-cbc -md sha512 -pbkdf2 -iter 1024 -salt -in "$DECFILE" -out "$ENCFILE" && \
    [[ -f "$ENCFILE" ]] && \
    chmod --reference="$DECFILE" "$ENCFILE" ) && return 0 || return 1
}

function decrypt_file() {
  ENCFILE="$1"
  DECFILE="$2"
  ( [[ -n $ENCFILE ]] && \
    [[ -r "$ENCFILE" ]] && \
    openssl enc -base64 -aes-256-cbc -md sha512 -pbkdf2 -iter 1024 -salt -d -in "$ENCFILE" -out "$DECFILE" && \
    [[ -f "$DECFILE" ]] && \
    chmod --reference="$ENCFILE" "$DECFILE" ) && return 0 || return 1
}

function restore_config_file {
  if [[ -n $CONFIG_FILE_RESTORE ]]; then
    mv -f "$CONFIG_FILE_RESTORE" "$CONFIG_FILE"
  fi
}

OP_MATCH=
EXE=
EXE_OP=
EXE_TARGET=
for i in ${WG_OPERATIONS[@]}; do
  OP="$(echo "$i" | cut -d';' -f1)"
  if [[ "$OP" == "$OPERATION" ]]; then
    OP_MATCH="$OP"
    EXE="$(echo "$i" | cut -d';' -f2)"
    EXE_OP="$(echo "$i" | cut -d';' -f3)"
    EXE_TARGET="$(echo "$i" | cut -d';' -f4 | sed "s/$IFACE_REPLACER/$INTERFACE/g")"
    break;
  fi
done

if [[ -n $OP_MATCH ]]; then

  if [[ "$EXE_OP" == "show" ]]; then
    if [[ -z $EXE_TARGET ]] || [[ "$EXE_TARGET" == "all" ]]; then
      "$EXE" "$EXE_OP"
    else
      "$EXE" "$EXE_OP" "$EXE_TARGET"
    fi

  elif [[ -r "$CONFIG_FILE" ]]; then

    if [[ "$OP_MATCH" == "enc" ]]; then
      CONFIG_FILE_ENC="$CONFIG_FILE.enc"
      if encrypt_file "$CONFIG_FILE" "$CONFIG_FILE_ENC"; then
        ls -l "$CONFIG_FILE_ENC"
        rm -vi "$CONFIG_FILE" && [[ ! -f "$CONFIG_FILE" ]] && mv -v "$CONFIG_FILE_ENC" "$CONFIG_FILE"
      else
        FINAL_EXIT_CODE=$?
        echo "Error encrypting configuration file "$CONFIG_FILE"" >&2
      fi

    elif [[ "$OP_MATCH" == "dec" ]]; then
      CONFIG_FILE_DEC="$CONFIG_FILE.dec"
      if decrypt_file "$CONFIG_FILE" "$CONFIG_FILE_DEC"; then
        ls -l "$CONFIG_FILE_DEC"
        rm -vi "$CONFIG_FILE" && [[ ! -f "$CONFIG_FILE" ]] && mv -v "$CONFIG_FILE_DEC" "$CONFIG_FILE"
      else
        FINAL_EXIT_CODE=$?
        echo "Error decrypting configuration file "$CONFIG_FILE"" >&2
      fi

    elif [[ "$EXE_OP" == "up" ]] && ( file "$CONFIG_FILE" | grep -q 'openssl enc' ); then
      CONFIG_FILE_ENC="$CONFIG_FILE.enc"
      CONFIG_FILE_DEC="$CONFIG_FILE.dec"
      if decrypt_file "$CONFIG_FILE" "$CONFIG_FILE_DEC"; then
        mv "$CONFIG_FILE" "$CONFIG_FILE_ENC"
        mv "$CONFIG_FILE_DEC" "$CONFIG_FILE"
        CONFIG_FILE_RESTORE="$CONFIG_FILE_ENC"
        trap "restore_config_file" EXIT
      else
        FINAL_EXIT_CODE=$?
        echo "Error decrypting configuration file "$CONFIG_FILE"" >&2
      fi
    fi

    if [[ -n $EXE_OP ]]; then
      "$EXE" "$EXE_OP" "$EXE_TARGET"
      FINAL_EXIT_CODE=$?
    fi

  else
    echo "Unable to read configuration file "$CONFIG_FILE"" >&2
    FINAL_EXIT_CODE=1
  fi

else
  echo "Usage:" >&2
  echo -e "\t$(basename $(test -L "$0" && readlink "$0" || echo "$0")) [start|stop|status|show] [interface]" >&2
  FINAL_EXIT_CODE=1
fi

[[ -n $FINAL_EXIT_CODE ]] && exit $FINAL_EXIT_CODE
