###############################################################################
# PATH
###############################################################################

if [[ $MACOS ]]; then
  [[ -d "/opt/homebrew/opt/coreutils/libexec/gnubin" ]]  && PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
  [[ -d "/opt/homebrew/opt/findutils/libexec/gnubin" ]]  && PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
  [[ -d "/opt/homebrew/opt/util-linux/bin" ]]            && PATH="/opt/homebrew/opt/util-linux/bin:$PATH"
  [[ -d "/opt/homebrew/opt/gnu-indent/libexec/gnubin" ]] && PATH="/opt/homebrew/opt/gnu-indent/libexec/gnubin:$PATH"
  [[ -d "/opt/homebrew/opt/gnu-sed/libexec/gnubin" ]]    && PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
  [[ -d "/opt/homebrew/opt/gnu-tar/libexec/gnubin" ]]    && PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"
  [[ -d "/opt/homebrew/opt/gnu-which/libexec/gnubin" ]]  && PATH="/opt/homebrew/opt/gnu-which/libexec/gnubin:$PATH"
  [[ -d "/opt/homebrew/opt/grep/libexec/gnubin" ]]       && PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
  [[ -d "/opt/homebrew/opt/openssl@1.1/bin" ]]           && PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"
  [[ -d "/opt/homebrew/bin" ]]                           && PATH="/opt/homebrew/bin:$PATH"
  [[ -d "/opt/homebrew/sbin" ]]                          && PATH="/opt/homebrew/sbin:$PATH"
fi

if [[ $WINDOWS10 ]]; then
  if command -v cygpath >/dev/null 2>&1; then
    if [[ -n $USERPROFILE ]]; then
      [[ -d "$(cygpath -u $USERPROFILE)"/scoop/shims ]] && \
        PATH="$(cygpath -u $USERPROFILE)"/scoop/shims:"$PATH"
      [[ -d "$(cygpath -u $USERPROFILE)"/scoop/apps/python/current/Scripts ]] && \
        PATH="$(cygpath -u $USERPROFILE)"/scoop/apps/python/current/Scripts:"$PATH"
    fi
    [[ -d "$(cygpath -u $SYSTEMROOT)"/System32/OpenSSH ]] && \
      PATH="$(cygpath -u $SYSTEMROOT)"/System32/OpenSSH:"$PATH"
  fi
fi

[[ -d /snap/bin ]] && PATH="/snap/bin:$PATH"

[[ -d $HOME/bin/devel ]] && PATH="$HOME/bin/devel:$PATH"
[[ -d $HOME/bin ]] && PATH="$HOME/bin:$PATH"

[[ -d $HOME/.local/bin/devel ]] && PATH="$HOME/.local/bin/devel:$PATH"
[[ -d $HOME/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"

###############################################################################
# LD_LIBRARY_PATH
###############################################################################
# export LD_LIBRARY_PATH=.:~/lib:~/lib32

###############################################################################
# development
###############################################################################
export DEVEL_ROOT=$HOME/devel
