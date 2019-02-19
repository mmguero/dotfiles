if [ -d ~/.anyenv ]; then
  export ANYENV_ROOT="$HOME/.anyenv"
  [[ -d $ANYENV_ROOT/bin ]] && PATH="$ANYENV_ROOT/bin:$PATH"
  eval "$(anyenv init -)"
fi

if [ $GOENV_ROOT ]; then
  export GOROOT="$(goenv prefix)"
fi

export GOPATH=$DEVEL_ROOT/gopath
[[ -d $GOPATH/bin ]] && PATH="$GOPATH/bin:$PATH"

if [ $PYENV_ROOT ]; then
  [[ -r $PYENV_ROOT/completions/pyenv.bash ]] && . $PYENV_ROOT/completions/pyenv.bash
  [[ -d $PYENV_ROOT/plugins/pyenv-virtualenv ]] && eval "$(pyenv virtualenv-init -)"
fi

[[ -d $HOME/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
