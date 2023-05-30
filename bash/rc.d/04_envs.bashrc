# preferrably everything will be set up using asdf

if [[ -d "${ASDF_DIR:-$HOME/.asdf}" ]]; then
  . "${ASDF_DIR:-$HOME/.asdf}"/asdf.sh
  if [[ -n $BASH_VERSION ]] && [[ -n $ASDF_DIR ]] && [[ -r "$ASDF_DIR"/completions/asdf.bash ]]; then
    . "$ASDF_DIR"/completions/asdf.bash
  fi
fi

export PYTHONDONTWRITEBYTECODE=1
export BAT_THEME='Monokai Extended'

if [[ -n $ASDF_DIR ]]; then
  if asdf plugin list | grep -q golang; then
    [[ -z $GOROOT ]] && go version >/dev/null 2>&1 && export GOROOT="$(go env GOROOT)"
    [[ -z $GOPATH ]] && go version >/dev/null 2>&1 && export GOPATH="$(go env GOPATH)"
  fi
  if (asdf plugin list | grep -q rust) && (asdf current rust >/dev/null 2>&1); then
    . "$ASDF_DIR"/installs/rust/"$(asdf current rust | awk '{print $2}')"/env
  fi
fi

function asdf-latest () {
  for ACTION in install global; do
    asdf list | grep -P "^\S" | xargs -I XXX -r asdf "$ACTION" "XXX" latest
  done
}

function asdf-prune () {
  asdf list | grep -P -v "^\s*\*" | grep -P -B 1 "^\s" | grep -v "\-\-" | paste -s -d" \n" | xargs -r -l asdf uninstall
}
