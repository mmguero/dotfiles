###############################################################################
# BASH OPTIONS
###############################################################################
# don't put duplicate lines in the history and ignore same sucessive entries.
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="&:ls:ll:cd:history:h:[bf]g:exit:shred *:pwd:clear"
export HISTFILESIZE=1000000000
export HISTSIZE=1000000
export HISTTIMEFORMAT="[%Y-%m-%d %H:%M:%S] "

shopt -s extglob
shopt -s dotglob
shopt -s cdspell
shopt -s histverify
shopt -s histappend
shopt -u progcomp

# Configuration for the command line tool "hh" (history searcher to replace ctrl-r, brew install hh)
export HH_CONFIG=hicolor,rawhistory,favorites   # get more colors

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
command -v lesspipe >/dev/null 2>&1 && eval "$(lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [[ -z "$debian_chroot" ]] && [[ -r /etc/debian_chroot ]]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/$HOME/~}\007"'
    ;;
*)
    ;;
esac

###############################################################################
# mappings/environment variables cross-platform use
###############################################################################

# determine OS
unset MACOS
unset LINUX
unset WINDOWS10
unset LC_WINDOWS10

if [[ $(uname -s) = 'Darwin' ]]; then
  export MACOS=0
elif [[ -n $MSYSTEM ]] || grep -q Microsoft /proc/version 2>/dev/null; then
  export WINDOWS10=0
  export LC_WINDOWS10=$WINDOWS10
  alias open='explorer.exe'
  [[ -n $MSYSTEM ]] && export MSYS=winsymlinks:nativestrict
else
  shopt -s nocasematch
  export LINUX=0
  if [[ "$(xdg-mime query default inode/directory 2>/dev/null)" =~ "thunar" ]]; then
    alias open="XDG_CURRENT_DESKTOP='XFCE' xdg-open"
  else
    alias open="xdg-open"
  fi
fi

function o() {
  if [[ $# -eq 0 ]]; then
    open .
  else
    for FILE in "$@"; do
      open "$FILE"
    done
  fi
}

###############################################################################

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"

if [[ $LINUX ]]; then

  [[ -r "/etc/bash_completion" ]] && . "/etc/bash_completion"

  if [[ $TILIX_ID ]] || [[ $VTE_VERSION ]]; then
    [[ -r "/etc/profile.d/vte.sh" ]] && . "/etc/profile.d/vte.sh" || . /etc/profile.d/vte-*.sh
  fi

fi

if [[ $MACOS ]]; then
  [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
  [[ -r "$HOME/.iterm2_shell_integration.bash" ]] && . "$HOME/.iterm2_shell_integration.bash"
  bind '"\e[5C": forward-word'
  bind '"\e[5D": backward-word'
  bind '"\e[1;5C": forward-word'
  bind '"\e[1;5D": backward-word'
fi

