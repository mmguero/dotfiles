###############################################################################
# BASH PROMPT
###############################################################################

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] ; then
  [[ -r "/usr/bin/neofetch" ]] && neofetch || ( [[ -r "/usr/bin/screenfetch" ]] && screenfetch )
fi

PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

export PRIMARY_IP=$(ip route get 255.255.255.255 2>/dev/null | grep -Po '(?<=src )(\d{1,3}.){4}' | sed "s/ //g")

unset HASHER
HASHERS=(sha512sum sha384sum sha256sum sha224sum sha1sum md5sum)
for i in ${HASHERS[@]}; do command -v "$i" >/dev/null 2>&1 && HASHER="$i" && break; done
PROMPT_STRING="$((hostname -A ; echo $PRIMARY_IP ; whoami ; lsb_release -s -d) 2>/dev/null | tr -d "\n" | tr -d " ")"
PROMPT_SEED="$(echo "$PROMPT_STRING" | $HASHER | awk '{print $1}')"
PROMPT_COLOR="$(context-color -c "echo $PROMPT_SEED" -p)"

if [ -f /.dockerenv ]; then
  # DOCKER: we are inside a container, change a color or do anything else different you'd like to do
  PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[0$PROMPT_COLOR\]@\h\[\033[1;30m\]:\[\033[01;34m\]\W\[\033[00m\]\[\033[01;30m\]\[\033[01;37m\]\$ \[\033[00;37m\]"
  alias chromium="chromium --no-sandbox"
  alias chrome="google-chrome --no-sandbox"

else
  PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[0$PROMPT_COLOR\]@\h\[\033[1;30m\]:\[\033[01;34m\]\W\[\033[00m\]\[\033[01;30m\]\$(parse_git_branch)\[\033[01;37m\]\$ \[\033[00;37m\]"
  [ $WINDOWS10 ] && cd ~
fi
