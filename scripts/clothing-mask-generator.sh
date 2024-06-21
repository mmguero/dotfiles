#!/usr/bin/env bash

set -u
set -o pipefail
shopt -s nullglob

ENCODING="utf-8"

function base () {
  echo "${1%.*}"
}

if ! ( command -v convert && command -v rembg ) >/dev/null 2>&1; then
  echo "$(basename "${BASH_SOURCE[0]}") requires convert and rembg" >&2
  exit 1
fi

for IMG in "$@"; do
    if [[ -f "${IMG}" ]]; then
        IMG_EXT="${IMG##*.}"
        IMG_MASK_FINAL="$(base "${IMG}")_mask.${IMG_EXT}"
        if [[ -f "${IMG_MASK_FINAL}" ]]; then
            echo "\"${IMG_MASK_FINAL}\" already exists for \"${IMG}\""
        else
            MASKS=()
            echo -n "Generating \"${IMG_MASK_FINAL}\" for \"${IMG}\"... "

            # generate masks for upper/lower/full
            for SEG in upper lower full; do
                IMG_MASK="$(base "${IMG}")_${SEG}.${IMG_EXT}"
                rembg i -m u2net_cloth_seg -om \
                    -x "{\"cc\": \"${SEG}\"}" "${IMG}" \
                    "${IMG_MASK}" && \
                [[ -f "${IMG_MASK}" ]] && \
                MASKS+=( "${IMG_MASK}" )
            done

            # composite masks into a single image
            if [[ ${#MASKS[@]} -eq 1 ]]; then
                cp "${MASKS[0]}" "${IMG_MASK_FINAL}"
            elif [[ ${#MASKS[@]} -eq 2 ]]; then
                convert "${MASKS[0]}" "${MASKS[1]}" -compose Lighten -composite "${IMG_MASK_FINAL}"
            elif [[ ${#MASKS[@]} -eq 3 ]]; then
                convert \( "${MASKS[0]}" "${MASKS[1]}" -compose Lighten -composite \) \
                     "${MASKS[2]}" -compose Lighten -composite "${IMG_MASK_FINAL}"
            fi

            # clean up
            for MASK in "${MASKS[@]}"; do
                rm -f "${MASK}"
            done
            echo "done."
        fi
    fi
done
