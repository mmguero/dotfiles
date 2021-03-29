#!/data/data/com.termux/files/usr/bin/bash

function urldecode() {
  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

args=("$@")
IFS=, eval 'joined="${args[*]}"'
IFS=, read -ra sendfiles <<< "$joined"

for i in "${!sendfiles[@]}"; do
  sendfiles[$i]="$(urldecode "${sendfiles[$i]}")"
  if [[ ${sendfiles[$i]} == /mnt/pass_through/0/* ]]; then
    sendfiles[$i]="$(echo -n "${sendfiles[$i]}"| sed "s@^/mnt/pass_through/0/@/storage/@" )"
  fi
done

wormhole --transit-helper tcp:guero.top:4001 send "${sendfiles[@]}"
