# preferrably everything will be set up using asdf

if [[ -d "${ASDF_DIR:-$HOME/.asdf}" ]]; then
  . "${ASDF_DIR:-$HOME/.asdf}"/asdf.sh
  if [[ -n $BASH_VERSION ]] && [[ -n $ASDF_DIR ]] && [[ -r "$ASDF_DIR"/completions/asdf.bash ]]; then
    . "$ASDF_DIR"/completions/asdf.bash
  fi
fi
export PYTHONDONTWRITEBYTECODE=1

if [[ -z "$GOPATH" ]]; then
  export GOPATH="$HOME/go"
fi
[[ -d "$GOPATH"/bin ]] && PATH="$GOPATH/bin:$PATH"

[[ -d $HOME/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"

