# preferrably everything will be set up using anyenv

if [ -d ~/.anyenv ]; then
  export ANYENV_ROOT="$HOME/.anyenv"
  [[ -d $ANYENV_ROOT/bin ]] && PATH="$ANYENV_ROOT/bin:$PATH"
  eval "$(anyenv init -)"
fi

# alternately they may be set up individually

if [ -z "$PYENV_ROOT" ] && [ -d ~/.pyenv ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  [[ -d $PYENV_ROOT/bin ]] && PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

if [ -z "$RBENV_ROOT" ] && [ -d ~/.rbenv ]; then
  export RBENV_ROOT="$HOME/.rbenv"
  [[ -d $RBENV_ROOT/bin ]] && PATH="$RBENV_ROOT/bin:$PATH"
  eval "$(rbenv init -)"
fi

if [ -z "$GOENV_ROOT" ] && [ -d ~/.goenv ]; then
  export GOENV_ROOT="$HOME/.goenv"
  [[ -d $GOENV_ROOT/bin ]] && PATH="$GOENV_ROOT/bin:$PATH"
  eval "$(goenv init -)"
fi

if [ -z "$NODENV_ROOT" ] && [ -d ~/.nodenv ]; then
  export NODENV_ROOT="$HOME/.nodenv"
  [[ -d $NODENV_ROOT/bin ]] && PATH="$NODENV_ROOT/bin:$PATH"
  eval "$(nodenv init -)"
fi

if [ -z "$PLENV_ROOT" ] && [ -d ~/.plenv ]; then
  export PLENV_ROOT="$HOME/.plenv"
  [[ -d $PLENV_ROOT/bin ]] && PATH="$PLENV_ROOT/bin:$PATH"
  eval "$(plenv init -)"
fi

# once we've sourced things for paths, set up any other custom stuf the envs need

if [ $PYENV_ROOT ]; then
  [[ -r $PYENV_ROOT/completions/pyenv.bash ]] && . $PYENV_ROOT/completions/pyenv.bash
  [[ -d $PYENV_ROOT/plugins/pyenv-virtualenv ]] && eval "$(pyenv virtualenv-init -)"
  export PYTHONDONTWRITEBYTECODE=1
fi

if [ $GOENV_ROOT ]; then
  export GOROOT="$(goenv prefix)"
  [[ -d "$GOROOT"/bin ]] && PATH="$GOROOT/bin:$PATH"
fi
if [ -z "$GOPATH" ]; then
  export GOPATH="$HOME/go"
fi
[[ -d "$GOPATH"/bin ]] && PATH="$GOPATH/bin:$PATH"

[[ -d $HOME/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"

