###############################################################################
# BASH PROMPT
###############################################################################

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] ; then
  [[ -r "/usr/bin/neofetch" ]] && neofetch || ( [[ -r "/usr/bin/screenfetch" ]] && screenfetch )
fi

PRIMARY_IP=$(ip route get 255.255.255.255 2>/dev/null | grep -Po '(?<=src )(\d{1,3}.){4}' | sed "s/ //g")

PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

if [ -f /.dockerenv ]; then
  PS1='🐳  \u \[\e[1;36m\]\h \[\e[1;34m\]\W\[\e[0;35m\] \[\e[1;36m\]# \[\e[0m\]'

else
  unset HASHER
  HASHERS=(sha512sum sha384sum sha256sum sha224sum sha1sum md5sum)
  for i in ${HASHERS[@]}; do command -v "$i" >/dev/null 2>&1 && HASHER="$i" && break; done
  PROMPT_STRING="$(((timeout 5 hostname -A || hostname) | xargs -n1 | sort -u | xargs ; echo $PRIMARY_IP ; whoami ; lsb_release -s -d) 2>/dev/null | tr -d "\n" | tr -d " ")"
  PROMPT_SEED="$(echo "$PROMPT_STRING" | $HASHER | awk '{print $1}')"
  PS1="\`if [ \$? = 0 ]; then echo \[\e[32m\]✔\[\e[0m\]; else echo \[\e[31m\]✘\[\e[0m\]; fi\` \[\e[01;49;39m\]\u\[\e[00m\]\[\e[01;49;39m\]@$(context-color -c "echo $PROMPT_SEED" -p 2>/dev/null)\h\[\e[0m\]\[\e[00m\] \[\e[1;49;34m\]\W\[\e[0m\] \[\e[38;5;151m\]\$(parse_git_branch 2>/dev/null)\[\e[0m\]▶ "
  [ $WINDOWS10 ] && cd ~
fi
