#!/usr/bin/env bash

# wwg.sh
# a wrapper script for wg/wg-quick/systemctl wireguard operations

# The idea is you create your wireguard config file (eg, `wg0.conf`),
# then run `wwg.sh enc wg0.conf` to encrypt it. Then, you can use `wwg.sh up wg0.conf`
# which will temporarily decrypt the file, run `wg-quick up` for that interface with
# the decrypted config file, then shred it so the plaintext version doesn't remain on
# disk for longer than the time the `wg-quick` operation takes.

# Usage:
# wwg.sh [operation] [interface]

OPERATION="$1"
INTERFACE="$2"
FINAL_EXIT_CODE=

# Operations include:
#   up - run wg-quick up (detects and handles encrypted configuration files)
#   down - run wg-quick down
#   enc - encrypt a config file
#   dec - decrypt a config file (e.g., for when you need to make edits to it)
#   show - run wg show (don't confuse with status)
#   status - run systemctl status wg-quick@XXX.service
#   enable - run systemctl enable wg-quick@XXX.service
#   disable - run systemctl enable wg-quick@XXX.service
#   start - run systemctl start wg-quick@XXX.service (don't confuse with up; doesn't handle encrypted configuration files)
#   stop - run systemctl stop wg-quick@XXX.service (don't confuse with down)

# if your wireguard configuration directory is something other than /etc/wireguard, you can override it
# with the WIREGUARD_CONFIG_DIR environment variable
CONFIG_DIR=${WIREGUARD_CONFIG_DIR:-"/etc/wireguard"}
CONFIG_FILE="$CONFIG_DIR/$INTERFACE.conf"
CONFIG_FILE_RESTORE=

# map a user-supplied operation to the exutable, executable operation, and argument in which the interface should reside
# op;exe;exe_op;iface_replacer
IFACE_REPLACER=XXX
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

# shred a file if possible, and rm it if not
function shred_file {
  TARGET="$1"
  if [[ -n $TARGET ]] && [[ -f "$TARGET" ]]; then
    type shred >/dev/null 2>&1 && shred -f -u "$TARGET" || rm -f "$TARGET"
  fi
  [[ -n $TARGET ]] && [[ ! -f "$TARGET" ]] && return 0 || return 1
}

# shred a file with user-provided confirmation
function shred_file_confirm {
  TARGET="$1"
  RETURN_CODE=1
  read -p "Remove "$TARGET" [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    shred_file "$TARGET"
    RETURN_CODE=$?
  fi
  return $RETURN_CODE
}

# encrypt a file (openssl will prompt for the password); does not allow encrypting an already encrypted file
function encrypt_file() {
  DECFILE="$1"
  ENCFILE="$2"
  ( [[ -n $DECFILE ]] && \
    [[ -r "$DECFILE" ]] && \
    ( ! ( file "$DECFILE" | grep -q 'openssl enc' ) ) && \
    openssl enc -base64 -aes-256-cbc -md sha512 -pbkdf2 -iter 1024 -salt -in "$DECFILE" -out "$ENCFILE" && \
    [[ -f "$ENCFILE" ]] && \
    chmod --reference="$DECFILE" "$ENCFILE" ) && return 0 || return 1
}

# decrypt a file (openssl will prompt for the password)
function decrypt_file() {
  ENCFILE="$1"
  DECFILE="$2"
  ( [[ -n $ENCFILE ]] && \
    [[ -r "$ENCFILE" ]] && \
    openssl enc -d -base64 -aes-256-cbc -md sha512 -pbkdf2 -iter 1024 -salt -in "$ENCFILE" -out "$DECFILE" && \
    [[ -f "$DECFILE" ]] && \
    chmod --reference="$ENCFILE" "$DECFILE" ) && return 0 || return 1
}

# restore the contents original config file ($CONFIG_FILE) if the variable $CONFIG_FILE_RESTORE is set and that file exists
function restore_config_file {
  if [[ -n $CONFIG_FILE_RESTORE ]]; then
    shred_file "$CONFIG_FILE"
    mv -f "$CONFIG_FILE_RESTORE" "$CONFIG_FILE"
  fi
}

# determine the operation provided by the user
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
    # if "all" or "" is provided for the interface, show all
    if [[ -z $EXE_TARGET ]] || [[ "$EXE_TARGET" == "all" ]]; then
      "$EXE" "$EXE_OP"
    else
      "$EXE" "$EXE_OP" "$EXE_TARGET"
    fi

  elif [[ -r "$CONFIG_FILE" ]]; then
    # only proceed if /etc/wireguard/XXXX.conf exists

    if [[ "$OP_MATCH" == "enc" ]]; then
      # encrypt a config file but that's all
      CONFIG_FILE_ENC="$CONFIG_FILE.enc"
      if encrypt_file "$CONFIG_FILE" "$CONFIG_FILE_ENC"; then
        ls -l "$CONFIG_FILE_ENC"
        # if requested, replace the original with the encrypted version
        shred_file_confirm "$CONFIG_FILE" && mv -v "$CONFIG_FILE_ENC" "$CONFIG_FILE"
      else
        FINAL_EXIT_CODE=$?
        echo "Error encrypting configuration file "$CONFIG_FILE"" >&2
      fi

    elif [[ "$OP_MATCH" == "dec" ]]; then
      # decrypt a config file but that's all
      CONFIG_FILE_DEC="$CONFIG_FILE.dec"
      if decrypt_file "$CONFIG_FILE" "$CONFIG_FILE_DEC"; then
        ls -l "$CONFIG_FILE_DEC"
        # if requested, replace the encrypted version with the decrypted version
        shred_file_confirm "$CONFIG_FILE" && mv -v "$CONFIG_FILE_DEC" "$CONFIG_FILE"
      else
        FINAL_EXIT_CODE=$?
        echo "Error decrypting configuration file "$CONFIG_FILE"" >&2
      fi

    elif [[ "$EXE_OP" == "up" ]] && ( file "$CONFIG_FILE" | grep -q 'openssl enc' ); then
      # if we're doing an "up" operation and the file is encrypted, decrypt it first
      CONFIG_FILE_ENC="$CONFIG_FILE.enc"
      CONFIG_FILE_DEC="$CONFIG_FILE.dec"
      if decrypt_file "$CONFIG_FILE" "$CONFIG_FILE_DEC"; then
        mv "$CONFIG_FILE" "$CONFIG_FILE_ENC"
        mv "$CONFIG_FILE_DEC" "$CONFIG_FILE"
        # ensure the decrypted version of the file is erased again before we exit
        CONFIG_FILE_RESTORE="$CONFIG_FILE_ENC"
        trap "restore_config_file" EXIT
      else
        FINAL_EXIT_CODE=$?
        echo "Error decrypting configuration file "$CONFIG_FILE"" >&2
      fi
    fi

    if [[ -n $EXE_OP ]]; then
      # perform the actual operation (wg, systemctl, whatever)
      "$EXE" "$EXE_OP" "$EXE_TARGET"
      FINAL_EXIT_CODE=$?
    fi

  else
    echo "Unable to read configuration file "$CONFIG_FILE"" >&2
    FINAL_EXIT_CODE=1
  fi

else
  echo "Usage:" >&2
  echo -e "\t$(basename $(test -L "$0" && readlink "$0" || echo "$0")) [operation] [interface]" >&2
  FINAL_EXIT_CODE=1
fi

[[ -n $FINAL_EXIT_CODE ]] && exit $FINAL_EXIT_CODE
