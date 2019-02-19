###############################################################################
# PATH
###############################################################################

if [ $MACOS ]; then
  [[ -d "/usr/local/opt/coreutils/libexec/gnubin" ]]  && PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/findutils/libexec/gnubin" ]]  && PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-indent/libexec/gnubin" ]] && PATH="/usr/local/opt/gnu-indent/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-sed/libexec/gnubin" ]]    && PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-tar/libexec/gnubin" ]]    && PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/gnu-which/libexec/gnubin" ]]  && PATH="/usr/local/opt/gnu-which/libexec/gnubin:$PATH"
  [[ -d "/usr/local/opt/grep/libexec/gnubin" ]]       && PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
fi

[[ -d $HOME/bin/devel ]] && PATH="$HOME/bin/devel:$PATH"

[[ -d $HOME/bin ]] && PATH="$HOME/bin:$PATH"

[[ -d $HOME/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"

###############################################################################
# LD_LIBRARY_PATH
###############################################################################
export LD_LIBRARY_PATH=.:~/lib:~/lib32

[[ -r "/opt/intel/ipp/bin/ippvars.sh" ]] && . "/opt/intel/ipp/bin/ippvars.sh" intel64

###############################################################################
# development
###############################################################################
export DEVEL_ROOT=$HOME/devel
