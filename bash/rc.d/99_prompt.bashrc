###############################################################################
# BASH PROMPT
###############################################################################

if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]] ; then
  command -v neofetch >/dev/null 2>&1 && neofetch || ( command -v screenfetch >/dev/null 2>&1 && screenfetch )
fi

PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

if command -v starship >/dev/null 2>&1; then

  [[ $WINDOWS10 ]] && \
    command -v cygpath >/dev/null 2>&1 && \
    [[ -f ~/.config/starship.toml ]] && \
    export STARSHIP_CONFIG="$(cygpath -a -w ~/.config/starship.toml)"

  eval "$(starship init bash)"

else
  ##### Colors ###################################################################
  COLOR_RED=$(tput sgr0 && tput setaf 1)
  COLOR_GREEN=$(tput sgr0 && tput setaf 2)
  COLOR_YELLOW=$(tput sgr0 && tput setaf 3)
  COLOR_DARK_BLUE=$(tput sgr0 && tput setaf 4)
  COLOR_BLUE=$(tput sgr0 && tput setaf 6)
  COLOR_PURPLE=$(tput sgr0 && tput setaf 5)
  COLOR_PINK=$(tput sgr0 && tput bold && tput setaf 5)
  COLOR_LIGHT_GREEN=$(tput sgr0 && tput bold && tput setaf 2)
  COLOR_LIGHT_RED=$(tput sgr0 && tput bold && tput setaf 1)
  COLOR_LIGHT_CYAN=$(tput sgr0 && tput bold && tput setaf 6)
  COLOR_CYAN=$(tput sgr0 && tput setaf 6)
  COLOR_RESET=$(tput sgr0)
  BOLD=$(tput bold)

  EXCLUDE_CONTEXT_COLORS="0,1,7,15,235"

  ERROR_TEST="
    if [[ \$? = \"0\" ]]; then
      RESULT_COLOR=\$COLOR_GREEN
    else
      RESULT_COLOR=\$COLOR_RED
    fi
    echo -e \"\$RESULT_COLOR\""

  if [[ -f /.dockerenv ]] || ( mount | grep -q "overlay on / " ); then
    PS1="\[$COLOR_BLUE\].\[$COLOR_RESET\]\u \[$COLOR_GREEN\]\h \[$COLOR_DARK_BLUE\]\W\[$COLOR_RESET\]> "
    unalias cat

  else
    command -v ip >/dev/null 2>&1 && PRIMARY_IP=$(ip route get 255.255.255.255 2>/dev/null | grep -Po '(?<=src )(\d{1,3}.){4}' | sed "s/ //g") || PRIMARY_IP='127.0.0.1'
    unset HASHER
    HASHERS=(sha512sum sha384sum sha256sum sha224sum sha1sum md5sum)
    for i in ${HASHERS[@]}; do command -v "$i" >/dev/null 2>&1 && HASHER="$i" && break; done
    PROMPT_STRING="$(((timeout 5 hostname -A || hostname) | xargs -n1 | sort -u | xargs ; echo $PRIMARY_IP ; whoami ; lsb_release -s -d) 2>/dev/null | tr -d "\n" | tr -d " ")"
    PROMPT_SEED="$(echo "$PROMPT_STRING" | $HASHER | awk '{print $1}')"
    PS1="\u\[\$(${ERROR_TEST})\]@\[$COLOR_RESET\]$(/usr/bin/env bash context-color -c "echo $PROMPT_SEED" -e "$EXCLUDE_CONTEXT_COLORS" -p 2>/dev/null)\h \[$COLOR_CYAN\]\W \[$COLOR_DARK_BLUE\]\$(parse_git_branch 2>/dev/null)\[$COLOR_RESET\]› "
    [[ $WINDOWS10 ]] && cd ~
  fi
fi

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
