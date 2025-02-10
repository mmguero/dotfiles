# preferrably everything will be set up using asdf

export PYTHONDONTWRITEBYTECODE=1
export BAT_THEME='Monokai Extended'
export ASDF_DATA_DIR="$HOME/.asdf"

if command -v asdf >/dev/null 2>&1; then

  [[ -d "${ASDF_DATA_DIR}" ]] && export PATH="${ASDF_DATA_DIR}/shims:$PATH"

  [[ -n $BASH_VERSION ]] && . <(asdf completion bash)

  if asdf plugin list | grep -q golang; then
    [[ -z $GOROOT ]] && go version >/dev/null 2>&1 && export GOROOT="$(go env GOROOT)"
    [[ -z $GOPATH ]] && go version >/dev/null 2>&1 && export GOPATH="$(go env GOPATH)"
  fi

  if (asdf plugin list | grep -q rust) && (asdf current rust >/dev/null 2>&1); then
    . "$ASDF_DATA_DIR"/installs/rust/"$(asdf current rust | tail -n +2 | head -n 1 | awk '{print $2}')"/env
  fi

  function asdf-latest () {
    asdf list | grep -P "^\S" | xargs -I XXX -r asdf install "XXX" latest
    asdf list | grep -P "^\S" | xargs -I XXX -r asdf set -u "XXX" latest
  }

  function asdf-prune () {
    asdf list | grep -P -v "^\s*\*" | grep -P -B 1 "^\s" | grep -v "\-\-" | paste -s -d" \n" | xargs -r -l asdf uninstall
  }

  alias reshim='asdf reshim'
fi