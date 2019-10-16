###############################################################################
# BASH PROMPT
###############################################################################

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] ; then
  [[ -r "/usr/bin/neofetch" ]] && neofetch || ( [[ -r "/usr/bin/screenfetch" ]] && screenfetch )
fi

export PRIMARY_IP=$(ip route get 255.255.255.255 2>/dev/null | grep -Po '(?<=src )(\d{1,3}.){4}' | sed "s/ //g")

PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
PROMPT_COLOR="$(context-color -c "bash -c 'hostname; echo $PRIMARY_IP; whoami'" -p)"

if [ -f /.dockerenv ]; then
  # DOCKER: we are inside a container, change a color or do anything else different you'd like to do
  PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[0$PROMPT_COLOR\]@\h\[\033[1;30m\]:\[\033[01;34m\]\W\[\033[00m\]\[\033[01;30m\]\[\033[01;37m\]\$ \[\033[00;37m\]"
  alias chromium="chromium --no-sandbox"
  alias chrome="google-chrome --no-sandbox"

else
  PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\[\033[0$PROMPT_COLOR\]@\h\[\033[1;30m\]:\[\033[01;34m\]\W\[\033[00m\]\[\033[01;30m\]\$(parse_git_branch)\[\033[01;37m\]\$ \[\033[00;37m\]"
  [ $WINDOWS10 ] && cd ~
fi
