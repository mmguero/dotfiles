###############################################################################
# PATH
###############################################################################

if [[ $MACOS ]]; then
  [[ -d "/usr/local/opt/coreutils/libexec/gnubin" ]]  && PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/findutils/libexec/gnubin" ]]  && PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-indent/libexec/gnubin" ]] && PATH="/usr/local/opt/gnu-indent/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-sed/libexec/gnubin" ]]    && PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-tar/libexec/gnubin" ]]    && PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-which/libexec/gnubin" ]]  && PATH="/usr/local/opt/gnu-which/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/grep/libexec/gnubin" ]]       && PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/openssl@1.1/bin" ]]           && PATH="/usr/local/opt/openssl@1.1/bin:$PATH"
  [[ -d $HOME/tmp ]] && export TMPDIR="$HOME/tmp"
fi

if [[ $WINDOWS10 ]]; then
  command -v cygpath >/dev/null 2>&1 && \
    [[ -n $USERPROFILE ]] && \
    [[ -d "$(cygpath -u $USERPROFILE)"/scoop/shims ]] && \
    PATH="$(cygpath -u $USERPROFILE)"/scoop/shims:"$PATH"
    [[ -d "$(cygpath -u $USERPROFILE)"/scoop/apps/python/current/Scripts ]] && \
    PATH="$(cygpath -u $USERPROFILE)"/scoop/apps/python/current/Scripts:"$PATH"
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
