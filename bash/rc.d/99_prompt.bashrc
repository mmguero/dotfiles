###############################################################################
# BASH PROMPT
###############################################################################

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

WHALE_CHAR="🐳"
CHECK_CHAR="✔"
X_CHAR="✘"
PROMPT_CHAR="▶"
PRINT_WIDE_CHAR="echo -e \"\\[`tput sc`\\]  \\[`tput rc`\\]\\[\$1\\] \""
ERROR_TEST="
  if [[ \$? = \"0\" ]]; then
    RESULT_COLOR=\$COLOR_GREEN
    RESULT_CHAR=\$CHECK_CHAR
  else
    RESULT_COLOR=\$COLOR_RED
    RESULT_CHAR=\$X_CHAR
  fi
  echo -e \"\\[`tput sc`\\]  \\[`tput rc`\\]\$RESULT_COLOR\\[\$RESULT_CHAR\\] \""

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] ; then
  [[ -r "/usr/bin/neofetch" ]] && neofetch || ( [[ -r "/usr/bin/screenfetch" ]] && screenfetch )
fi

PRIMARY_IP=$(ip route get 255.255.255.255 2>/dev/null | grep -Po '(?<=src )(\d{1,3}.){4}' | sed "s/ //g")
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

if [ -f /.dockerenv ]; then
  PS1="\[$COLOR_RESET\]\$(${PRINT_WIDE_CHAR} $WHALE_CHAR) \[$COLOR_RESET\]\u \[$COLOR_GREEN\]\h \[$COLOR_DARK_BLUE\]\W \[$COLOR_GREEN\]# \[$COLOR_RESET\]"

else
  unset HASHER
  HASHERS=(sha512sum sha384sum sha256sum sha224sum sha1sum md5sum)
  for i in ${HASHERS[@]}; do command -v "$i" >/dev/null 2>&1 && HASHER="$i" && break; done
  PROMPT_STRING="$(((timeout 5 hostname -A || hostname) | xargs -n1 | sort -u | xargs ; echo $PRIMARY_IP ; whoami ; lsb_release -s -d) 2>/dev/null | tr -d "\n" | tr -d " ")"
  PROMPT_SEED="$(echo "$PROMPT_STRING" | $HASHER | awk '{print $1}')"
  PS1="\u \$(${ERROR_TEST})\[$COLOR_RESET\]$(/usr/bin/env bash context-color -c "echo $PROMPT_SEED" -p 2>/dev/null)\h \[$COLOR_CYAN\]\W \[$COLOR_DARK_BLUE\]\$(parse_git_branch 2>/dev/null)\[$COLOR_RESET\]\$(${PRINT_WIDE_CHAR} $PROMPT_CHAR) "
  [ $WINDOWS10 ] && cd ~
fi
