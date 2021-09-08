#!/data/data/com.termux/files/usr/bin/bash

function urldecode() {
  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

export CROC_RELAY=example.org:8000
export CROC_PASS=password

args=("$@")
IFS=, eval 'joined="${args[*]}"'
IFS=, read -ra sendfiles <<< "$joined"

for i in "${!sendfiles[@]}"; do
  sendfiles[$i]="$(urldecode "${sendfiles[$i]}")"
  if [[ ${sendfiles[$i]} == /mnt/pass_through/0/* ]]; then
    sendfiles[$i]="$(echo -n "${sendfiles[$i]}"| sed "s@^/mnt/pass_through/0/@/storage/@" )"
  fi
done

croc --yes send "${sendfiles[@]}"
