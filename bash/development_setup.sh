#!/bin/bash

PYTHON_VERSIONS=( 3.7.2 2.7.15 )
RUBY_VERSIONS=( 2.6.1 )
GOLANG_VERSIONS=( 1.11.5 )
NODEJS_VERSIONS=( 10.15.1 )
PERL_VERSIONS=( 5.28.1 )
DOCKER_COMPOSE_INSTALL_VERSION=( 1.23.2 )

# add to .bashrc after running this script:

# if [ -d ~/.anyenv ]; then
#   export ANYENV_ROOT="$HOME/.anyenv"
#   [[ -d $ANYENV_ROOT/bin ]] && PATH="$ANYENV_ROOT/bin:$PATH"
#   eval "$(anyenv init -)"
# fi

# if [ $GOENV_ROOT ]; then
#   export GOROOT="$(goenv prefix)"
# fi

# export GOPATH=$DEVEL_ROOT/gopath
# [[ -d $GOPATH/bin ]] && PATH="$GOPATH/bin:$PATH"

# if [ $PYENV_ROOT ]; then
#   [[ -r $PYENV_ROOT/completions/pyenv.bash ]] && . $PYENV_ROOT/completions/pyenv.bash
#   [[ -d $PYENV_ROOT/plugins/pyenv-virtualenv ]] && eval "$(pyenv virtualenv-init -)"
# fi


# determine OS
unset MACOS
unset LINUX
unset WINDOWS
if [ $(uname -s) = 'Darwin' ]; then
  export MACOS=0
elif grep -q Microsoft /proc/version; then
  export WINDOWS=0
  echo "Windows is not currently supported by this script."
  exit 1
else
  export LINUX=0
  export DEBIAN_FRONTEND=noninteractive
fi

# determine user and/or if we need to use sudo to install packages
if [ $MACOS ]; then
  SCRIPT_USER="$(whoami)"
  SUDO_CMD=""

elif [[ $EUID -eq 0 ]]; then
  SCRIPT_USER="root"
  SUDO_CMD=""

else
  SCRIPT_USER="$(whoami)"
  if [[ "$(sudo whoami)" == "root" ]]; then
    SUDO_CMD="sudo"
  else
    echo "This command must be run as root, or \"sudo\" must be available (in case packages must be installed)"
    exit 1
  fi
fi

# convenience function for installing git for cloning/downloading
function InstallCurlAndGit {
  if curl -V >/dev/null 2>&1 && git --version >/dev/null 2>&1 ; then
    echo "\"curl\" and \"git\" are already installed!"
  else
    echo "Installing curl and git..."
    if [ $MACOS ]; then
      brew install git # since Jaguar curl is already installed in MacOS
    elif [ $LINUX ]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1 && \
        $SUDO_CMD apt-get install -y curl git
    fi
  fi
}

# function to set up paths and init things after env installations
function EnvSetup {
  if [ -d ~/.anyenv ]; then
    export ANYENV_ROOT="$HOME/.anyenv"
    [[ -d $ANYENV_ROOT/bin ]] && PATH="$ANYENV_ROOT/bin:$PATH"
    eval "$(anyenv init -)"
  fi

  if [ $GOENV_ROOT ]; then
    export GOROOT="$(goenv prefix)"
  fi

  export GOPATH=$DEVEL_ROOT/gopath
  [[ -d $GOPATH/bin ]] && PATH="$GOPATH/bin:$PATH"

  if [ $PYENV_ROOT ]; then
    [[ -r $PYENV_ROOT/completions/pyenv.bash ]] && . $PYENV_ROOT/completions/pyenv.bash
    [[ -d $PYENV_ROOT/plugins/pyenv-virtualenv ]] && eval "$(pyenv virtualenv-init -)"
  fi
}

################################################################################
# brew on macOS
################################################################################
if [ $MACOS ]; then

  # install brew, if needed
  if ! brew info >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "\"brew\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      echo "Installing brew..."
      # kind of a chicken-egg situation here with curl/brew, but I think macOS has it installed already
      /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi
  else
    echo "\"brew\" is already installed!"
  fi # brew install check

  # install brew cask, if needed
  if ! brew info cask >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "\"brew cask\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      echo "Installing brew cask..."
      brew install cask
      brew tap caskroom/versions
    fi
  else
    echo "\"brew cask\" is already installed!"
  fi # brew cask install check
fi # MacOS check

InstallCurlAndGit

################################################################################
# anyenv
################################################################################
if [ -z $ANYENV_ROOT ]; then

  unset CONFIRMATION
  read -p "\"anyenv\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then

    InstallCurlAndGit
    pushd $HOME
    git clone https://github.com/riywo/anyenv ~/.anyenv
    EnvSetup
    if [ ! -d $HOME/.config/anyenv/anyenv-install ]; then
      anyenv install --init
    fi
    mkdir -p $(anyenv root)/plugins
    git clone https://github.com/znz/anyenv-update.git "$(anyenv root)"/plugins/anyenv-update

  fi # install anyenv confirmation
fi # .anyenv check

EnvSetup

if [ -n $ANYENV_ROOT ]; then

  # python
  if [ -z $PYENV_ROOT ]; then
    unset CONFIRMATION
    read -p "\"pyenv\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      anyenv install pyenv
      EnvSetup
      if [ $MACOS ]; then
        brew install readline xz openssl
      elif [ $LINUX ]; then
        $SUDO_CMD apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
                                     wget llvm libncurses5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev
      fi
      for ver in "${PYTHON_VERSIONS[@]}"; do
        if [ $MACOS ]; then
          CFLAGS="-I$(brew --prefix openssl)/include" \
          LDFLAGS="-L$(brew --prefix openssl)/lib" \
            pyenv install "$ver"
        else
          pyenv install "$ver"
        fi
      done
      pyenv global "${PYTHON_VERSIONS[@]}"
      mkdir -p "$(pyenv root)"/plugins/
      git clone https://github.com/pyenv/pyenv-update.git "$(pyenv root)"/plugins/pyenv-update
      git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
    fi
  fi

  # ruby
  if [ -z $RBENV_ROOT ]; then
    unset CONFIRMATION
    read -p "\"rbenv\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      anyenv install rbenv
      EnvSetup
      for ver in "${RUBY_VERSIONS[@]}"; do
        rbenv install "$ver"
      done
      rbenv global "${RUBY_VERSIONS[@]}"
      mkdir -p "$(rbenv root)"/plugins/
      git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
      git clone https://github.com/rkh/rbenv-update.git "$(rbenv root)"/plugins/rbenv-update
    fi
  fi

  # golang
  if [ -z $GOENV_ROOT ]; then
    unset CONFIRMATION
    read -p "\"goenv\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      anyenv install goenv
      EnvSetup
      for ver in "${GOLANG_VERSIONS[@]}"; do
        goenv install "$ver"
      done
      goenv global "${GOLANG_VERSIONS[@]}"
      mkdir -p "$(goenv root)"/plugins/
      git clone https://github.com/trafficgate/goenv-install-glide.git "$(goenv root)"/plugins/goenv-install-glide
    fi
  fi

  # nodejs
  if [ -z $NODENV_ROOT ]; then
    unset CONFIRMATION
    read -p "\"nodenv\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      anyenv install nodenv
      EnvSetup
      for ver in "${NODEJS_VERSIONS[@]}"; do
        nodenv install "$ver"
      done
      nodenv global "${NODEJS_VERSIONS[@]}"
      mkdir -p "$(nodenv root)"/plugins/
      git clone https://github.com/nodenv/node-build.git "$(nodenv root)"/plugins/node-build
      git clone https://github.com/nodenv/nodenv-update.git "$(nodenv root)"/plugins/nodenv-update
    fi
  fi

  # perl
  if [ -z $PLENV_ROOT ]; then
    unset CONFIRMATION
    read -p "\"plenv\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      anyenv install plenv
      EnvSetup
      for ver in "${PERL_VERSIONS[@]}"; do
        plenv install "$ver"
      done
      plenv global "${PERL_VERSIONS[@]}"
      mkdir -p "$(plenv root)"/plugins/
    fi
  fi

else
  echo "anyenv is not configured!"
  exit 1
fi

################################################################################
EnvSetup

################################################################################
# env packages
################################################################################
unset CONFIRMATION
read -p "Install common pip/go/etc. packages [Y/n]? " CONFIRMATION
CONFIRMATION=${CONFIRMATION:-Y}
if [[ $CONFIRMATION =~ ^[Yy] ]]; then

  if pip -V >/dev/null 2>&1 ; then
    pip install -U \
      bat \
      beautifulsoup4 \
      colored \
      cryptography \
      Cython \
      entrypoint2 \
      git+git://github.com/badele/gitcheck.git \
      git-up \
      numpy \
      ordered-set \
      pandas \
      patool \
      Pillow \
      psutil \
      pyunpack \
      scapy \
      scipy \
      urllib3
  fi

  if go version >/dev/null 2>&1 ; then
    go get -u -v github.com/rogpeppe/godef
    go get -u -v golang.org/x/tools/cmd/goimports
    go get -u -v golang.org/x/tools/cmd/gorename
    go get -u -v github.com/nsf/gocode
  fi
fi

################################################################################
# docker
################################################################################
if [ $MACOS ]; then

  # install docker-edge, if needed
  if ! brew cask info docker-edge >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "\"docker-edge\" cask is not installed, attempt to install docker-edge via brew [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      echo "Installing Docker Edge..."
      brew cask install docker-edge
      echo "Installed Docker Edge."
      echo "Please modify performance settings as needed"
    fi # docker install confirmation check
  else
    echo "\"docker-edge\" is already installed!"
  fi # docker-edge install check

elif [ $LINUX ]; then

  # install docker-ce, if needed
  if ! $SUDO_CMD docker info >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "\"docker info\" failed, attempt to install docker [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      InstallCurlAndGit

      $SUDO_CMD apt-get install \
                         apt-transport-https \
                         ca-certificates \
                         curl \
                         gnupg2 \
                         software-properties-common

      curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO_CMD apt-key add -

      echo "Installing Docker CE..."

      if grep -i Ubuntu /etc/issue >/dev/null 2>&1 ; then
        $SUDO_CMD add-apt-repository \
           "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
           $(lsb_release -cs) \
           stable"
      elif grep -i Debian /etc/issue >/dev/null 2>&1 ; then
        $SUDO_CMD add-apt-repository \
           "deb [arch=amd64] https://download.docker.com/linux/debian \
           $(lsb_release -cs) \
           stable"
      fi

      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      $SUDO_CMD apt-get install -y docker-ce

      if [[ "$SCRIPT_USER" != "root" ]]; then
        echo "Adding \"$SCRIPT_USER\" to group \"docker\"..."
        $SUDO_CMD usermod -a -G docker "$SCRIPT_USER"
        echo "You will need to log out and log back in for this to take effect"
      fi
    fi # docker install confirmation check

  else
    echo "\"docker\" is already installed!"
  fi # docker install check

  # install docker-compose, if needed
  if ! docker-compose version >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "\"docker-compose version\" failed, attempt to install docker-compose [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      if pip -V >/dev/null 2>&1 ; then
        echo "Installing Docker Compose via pip..."
        pip install docker-compose
        if ! docker-compose version >/dev/null 2>&1 ; then
          echo "Installing docker-compose failed"
          exit 1
        fi
      else
        echo "Installing Docker Compose via curl to /usr/local/bin..."
        InstallCurlAndGit
        $SUDO_CMD curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_INSTALL_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        $SUDO_CMD chmod +x /usr/local/bin/docker-compose
        if ! /usr/local/bin/docker-compose version >/dev/null 2>&1 ; then
          echo "Installing docker-compose failed"
          exit 1
        fi
      fi # pip vs. curl for docker-compose install
    fi # docker-compose install confirmation check
  else
    echo "\"docker-compose\" is already installed!"
  fi # docker-compose install check

fi # MacOS vs. Linux for docker

################################################################################
# other packages
################################################################################
if [ $MACOS ]; then

  unset CONFIRMATION
  read -p "Install common packages [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then

    brew install bash
    grep /usr/local/bin/bash /etc/shells || (echo '/usr/local/bin/bash' | sudo tee -a /etc/shells)

    # Add the following line to your ~/.bash_profile:
    #  [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
    brew install bash-completion

    # Commands also provided by macOS have been installed with the prefix "g".
    # If you need to use these commands with their normal names, you
    # can add a "gnubin" directory to your PATH from your bashrc like:
    #   PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
    brew install coreutils

    brew install diffutils
    brew install dos2unix

    # All commands have been installed with the prefix "g".
    # If you need to use these commands with their normal names, you
    # can add a "gnubin" directory to your PATH from your bashrc like:
    #   PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
    brew install findutils

    brew install gawk
    brew install git

    # GNU "indent" has been installed as "gindent".
    # If you need to use it as "indent", you can add a "gnubin" directory
    # to your PATH from your bashrc like:
    #     PATH="/usr/local/opt/gnu-indent/libexec/gnubin:$PATH"
    brew install gnu-indent

    # GNU "sed" has been installed as "gsed".
    # If you need to use it as "sed", you can add a "gnubin" directory
    # to your PATH from your bashrc like:
    #     PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
    brew install gnu-sed

    # GNU "tar" has been installed as "gtar".
    # If you need to use it as "tar", you can add a "gnubin" directory
    # to your PATH from your bashrc like:
    #     PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"
    brew install gnu-tar

    # GNU "which" has been installed as "gwhich".
    # If you need to use it as "which", you can add a "gnubin" directory
    # to your PATH from your bashrc like:
    #     PATH="/usr/local/opt/gnu-which/libexec/gnubin:$PATH"
    brew install gnu-which

    brew install gnutls

    # All commands have been installed with the prefix "g".
    # If you need to use these commands with their normal names, you
    # can add a "gnubin" directory to your PATH from your bashrc like:
    #   PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
    brew install grep

    brew install gzip
    brew install htop
    brew install iproute2mac
    brew install less
    brew install openssh
    brew install moreutils
    brew install p7zip
    brew install pigz
    brew install psgrep
    brew install psutils
    brew install screen
    brew install tree
    brew install unrar
    brew install vim
    brew install watch
    brew install wdiff
    brew install wget
  fi

  unset CONFIRMATION
  read -p "Install common casks [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    brew cask install diskwave
    brew cask install firefox
    brew cask install homebrew/cask-fonts/font-hack
    brew cask install iterm2
    brew cask install keepassxc
    brew cask install osxfuse
    brew cask install sublime-text
    brew cask install wireshark
  fi

elif [ $LINUX ]; then
  unset CONFIRMATION
  read -p "Install common packages [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    DEBIAN_PACKAGE_LIST=(
      apache2-utils
      apt-file
      apt-listchanges
      apt-show-versions
      apt-transport-https
      apt-utils
      autoconf
      automake
      autossh
      bash
      binutils
      bison
      bridge-utils
      btrfs-progs
      build-essential
      bzip2
      ca-certificates
      cgdb
      checkinstall
      cifs-utils
      cloc
      coreutils
      cmake
      cpio
      cryptmount
      cryptsetup
      curl
      dialog
      diffutils
      eject
      ethtool
      exfat-fuse
      exfat-utils
      fdisk
      file
      findutils
      flex
      fonts-hack
      fonts-hack-ttf
      fuseiso
      gdb
      git
      git-lfs
      gnupg2
      google-perftools
      grep
      gzip
      haveged
      htop
      iproute2
      less
      localepurge
      lshw
      lsof
      make
      moreutils
      mosh
      netsniff-ng
      netcat-traditional
      ngrep
      ntfs-3g
      openssh-client
      openresolv
      openvpn
      p7zip
      p7zip-full
      parted
      patch
      patchutils
      pigz
      pmount
      procps
      psmisc
      pv
      qemu-utils
      rar
      rename
      rsync
      screen
      sed
      socat
      sshfs
      strace
      subversion
      sudo
      sysstat
      tcpdump
      testdisk
      time
      tofrodos
      traceroute
      tshark
      tzdata
      ufw
      unrar
      unzip
      vim-tiny
      wget
      zlib1g
    )
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      sudo apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done
  fi

  unset CONFIRMATION
  read -p "Install common packages (GUI) [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    DEBIAN_PACKAGE_LIST=(
      dconf-cli
      fonts-hack
      ghex
      gparted
      keepassxc
      meld
      numix-gtk-theme
      numix-icon-theme
      regexxer
      sublime-text
      tilix
      wireshark
      xxdiff
      xxdiff-scripts
      xdiskusage
    )
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      sudo apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done
  fi

  unset CONFIRMATION
  read -p "Install common packages (media) [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    DEBIAN_PACKAGE_LIST=(
      audacity
      audacious
      gimp
      gimp-plugin-registry
      gimp-texturize
      recordmydesktop
      gtk-recordmydesktop
      ffmpeg
      mpv
      pithos
    )
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      sudo apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done
  fi

  unset CONFIRMATION
  read -p "Create missing common local config in home [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then

    touch ~/.hushlogin

    mkdir -p "$HOME/Desktop" "$HOME/download" "$HOME/media/music" "$HOME/media/images" "$HOME/media/video" "$HOME/tmp" "$HOME/bin"

    if [ ! -f ~/.vimrc ]; then
      echo "set nocompatible" > ~/.vimrc
    fi

    if [ ! -d ~/.ssh ]; then
      mkdir ~/.ssh
      chmod 700 ~/.ssh
    fi

    if [ ! -e ~/.ssh/config ]; then
      mkdir -p ~/.ssh/cm_socket
      chmod 700 ~/.ssh/cm_socket
      cat <<EOT >> ~/.ssh/config
# defaults
Host *
  ServerAliveInterval 120
  ControlMaster auto
  ControlPath ~/.ssh/cm_socket/%r@%h:%p
EOT
    fi
  fi

  unset CONFIRMATION
  read -p "Configure GDB [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then

    if [ ! -f ~/.gdbinit ]; then
      cat <<EOT >> ~/.gdbinit
set auto-load safe-path /
set print frame-arguments no
set print pretty on
set print null-stop
set print elements 1000
set print thread-events off
set history remove-duplicates unlimited
EOT

      mkdir -p ~/.config/gdb
      GDB_HEXDUMP_PY_B64="aW1wb3J0IGdkYgpmcm9tIGN1cnNlcy5hc2NpaSBpbXBvcnQgaXNncmFwaAoKZGVmIGdyb3Vwc19vZihpdGVyYWJsZSwgc2l6ZSwgZmlyc3Q9MCk6CiAgICBmaXJzdCA9IGZpcnN0IGlmIGZpcnN0ICE9IDAgZWxzZSBzaXplCiAgICBjaHVuaywgaXRlcmFibGUgPSBpdGVyYWJsZVs6Zmlyc3RdLCBpdGVyYWJsZVtmaXJzdDpdCiAgICB3aGlsZSBjaHVuazoKICAgICAgICB5aWVsZCBjaHVuawogICAgICAgIGNodW5rLCBpdGVyYWJsZSA9IGl0ZXJhYmxlWzpzaXplXSwgaXRlcmFibGVbc2l6ZTpdCgpjbGFzcyBIZXhEdW1wKGdkYi5Db21tYW5kKToKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzdXBlciAoSGV4RHVtcCwgc2VsZikuX19pbml0X18gKCdoZXgtZHVtcCcsIGdkYi5DT01NQU5EX0RBVEEpCgogICAgZGVmIGludm9rZShzZWxmLCBhcmcsIGZyb21fdHR5KToKICAgICAgICBhcmd2ID0gZ2RiLnN0cmluZ190b19hcmd2KGFyZykKCiAgICAgICAgYWRkciA9IGdkYi5wYXJzZV9hbmRfZXZhbChhcmd2WzBdKS5jYXN0KAogICAgICAgICAgICBnZGIubG9va3VwX3R5cGUoJ3ZvaWQnKS5wb2ludGVyKCkpCiAgICAgICAgaWYgbGVuKGFyZ3YpID09IDI6CiAgICAgICAgICAgICB0cnk6CiAgICAgICAgICAgICAgICAgYnl0ZXMgPSBpbnQoZ2RiLnBhcnNlX2FuZF9ldmFsKGFyZ3ZbMV0pKQogICAgICAgICAgICAgZXhjZXB0IFZhbHVlRXJyb3I6CiAgICAgICAgICAgICAgICAgcmFpc2UgZ2RiLkdkYkVycm9yKCdCeXRlIGNvdW50IG51bXN0IGJlIGFuIGludGVnZXIgdmFsdWUuJykKICAgICAgICBlbHNlOgogICAgICAgICAgICAgYnl0ZXMgPSA1MTIKCiAgICAgICAgaW5mZXJpb3IgPSBnZGIuc2VsZWN0ZWRfaW5mZXJpb3IoKQoKICAgICAgICBhbGlnbiA9IGdkYi5wYXJhbWV0ZXIoJ2hleC1kdW1wLWFsaWduJykKICAgICAgICB3aWR0aCA9IGdkYi5wYXJhbWV0ZXIoJ2hleC1kdW1wLXdpZHRoJykKICAgICAgICBpZiB3aWR0aCA9PSAwOgogICAgICAgICAgICB3aWR0aCA9IDE2CgogICAgICAgIG1lbSA9IGluZmVyaW9yLnJlYWRfbWVtb3J5KGFkZHIsIGJ5dGVzKQogICAgICAgIHByX2FkZHIgPSBpbnQoc3RyKGFkZHIpLCAxNikKICAgICAgICBwcl9vZmZzZXQgPSB3aWR0aAoKICAgICAgICBpZiBhbGlnbjoKICAgICAgICAgICAgcHJfb2Zmc2V0ID0gd2lkdGggLSAocHJfYWRkciAlIHdpZHRoKQogICAgICAgICAgICBwcl9hZGRyIC09IHByX2FkZHIgJSB3aWR0aAogICAgICAgIHN0YXJ0PShwcl9hZGRyKSAmIDB4ZmY7CgoKICAgICAgICBwcmludCAoJyAgICAgICAgICAgICAgICAgJyAsIGVuZD0iIikKICAgICAgICBwcmludCAoJyAgJy5qb2luKFsnJTAxWCcgJSAoaSYweDBmLCkgZm9yIGkgaW4gcmFuZ2Uoc3RhcnQsc3RhcnQrd2lkdGgpXSkgLCBlbmQ9IiIpCiAgICAgICAgcHJpbnQgKCcgJyAsIGVuZD0iIikKICAgICAgICBwcmludCAoJycuam9pbihbJyUwMVgnICUgKGkmMHgwZiwpIGZvciBpIGluIHJhbmdlKHN0YXJ0LHN0YXJ0K3dpZHRoKV0pICkKCiAgICAgICAgZm9yIGdyb3VwIGluIGdyb3Vwc19vZihtZW0sIHdpZHRoLCBwcl9vZmZzZXQpOgogICAgICAgICAgICBwcmludCAoJzB4JXg6ICcgJSAocHJfYWRkciwpICsgJyAgICcqKHdpZHRoIC0gcHJfb2Zmc2V0KSwgZW5kPSIiKQogICAgICAgICAgICBwcmludCAoJyAnLmpvaW4oWyclMDJYJyAlIChvcmQoZyksKSBmb3IgZyBpbiBncm91cF0pICsgXAogICAgICAgICAgICAgICAgJyAgICcgKiAod2lkdGggLSBsZW4oZ3JvdXApIGlmIHByX29mZnNldCA9PSB3aWR0aCBlbHNlIDApICsgJyAnLCBlbmQ9IiIpCiAgICAgICAgICAgIHByaW50ICgnICcqKHdpZHRoIC0gcHJfb2Zmc2V0KSArICAnJy5qb2luKAogICAgICAgICAgICAgICAgW2NociggaW50LmZyb21fYnl0ZXMoZywgYnl0ZW9yZGVyPSdiaWcnKSkgaWYgaXNncmFwaCggaW50LmZyb21fYnl0ZXMoZywgYnl0ZW9yZGVyPSdiaWcnKSAgICkgb3IgZyA9PSAnICcgZWxzZSAnLicgZm9yIGcgaW4gZ3JvdXBdKSkKICAgICAgICAgICAgcHJfYWRkciArPSB3aWR0aAogICAgICAgICAgICBwcl9vZmZzZXQgPSB3aWR0aAoKY2xhc3MgSGV4RHVtcEFsaWduKGdkYi5QYXJhbWV0ZXIpOgogICAgZGVmIF9faW5pdF9fKHNlbGYpOgogICAgICAgIHN1cGVyIChIZXhEdW1wQWxpZ24sIHNlbGYpLl9faW5pdF9fKCdoZXgtZHVtcC1hbGlnbicsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZ2RiLkNPTU1BTkRfREFUQSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBnZGIuUEFSQU1fQk9PTEVBTikKCiAgICBzZXRfZG9jID0gJ0RldGVybWluZXMgaWYgaGV4LWR1bXAgYWx3YXlzIHN0YXJ0cyBhdCBhbiAiYWxpZ25lZCIgYWRkcmVzcyAoc2VlIGhleC1kdW1wLXdpZHRoJwogICAgc2hvd19kb2MgPSAnSGV4IGR1bXAgYWxpZ25tZW50IGlzIGN1cnJlbnRseScKCmNsYXNzIEhleER1bXBXaWR0aChnZGIuUGFyYW1ldGVyKToKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzdXBlciAoSGV4RHVtcFdpZHRoLCBzZWxmKS5fX2luaXRfXygnaGV4LWR1bXAtd2lkdGgnLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGdkYi5DT01NQU5EX0RBVEEsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZ2RiLlBBUkFNX0lOVEVHRVIpCgogICAgc2V0X2RvYyA9ICdTZXQgdGhlIG51bWJlciBvZiBieXRlcyBwZXIgbGluZSBvZiBoZXgtZHVtcCcKCiAgICBzaG93X2RvYyA9ICdUaGUgbnVtYmVyIG9mIGJ5dGVzIHBlciBsaW5lIGluIGhleC1kdW1wIGlzJwoKSGV4RHVtcCgpCkhleER1bXBBbGlnbigpCkhleER1bXBXaWR0aCgpCg=="
      echo "$GDB_HEXDUMP_PY_B64" | base64 -d > ~/.config/gdb/hexdump.py
      chmod +x ~/.config/gdb/hexdump.py
      cat <<EOT >> ~/.gdbinit

python
sys.path.insert(0, '$HOME/.config/gdb')
import hexdump
end
alias -a hd = hex-dump
EOT

      if [ ! -d ~/.config/gdb/peda ]; then
        git clone https://github.com/longld/peda.git ~/.config/gdb/peda
      fi
      echo "" >> ~/.gdbinit
      echo "# source ~/.config/gdb/peda/peda.py" >> ~/.gdbinit
    fi
  fi

  if [ ! -e ~/.cgdb/cgdbrc ]; then
    mkdir -p ~/.cgdb
    cat <<EOT >> ~/.cgdb/cgdbrc
:set autosourcereload
:set arrowstyle=long
:set ignorecase on
:set tabstop=2
map <F2> i<Space>set<Space>scheduler-locking<Space>step<CR><Space>set<Space>print<Space>pretty<Space>on<CR><Space>set<Space>print<Space>thread-events<Space>off<CR><Space>set<Space>print<Space>null-stop<Space>on<CR><Space>set<Space>print<Space>frame-arguments<Space>no<CR><Esc>
map r i<Space>run<CR><Esc>
map c i<Space>continue<CR><Esc>
map f i<Space>finish<CR><Esc>
map n i<Space>next<CR><Esc>
map s i<Space>step<CR><Esc>
map u :up<CR>
map d :down<CR>
EOT
  fi

  unset CONFIRMATION
  read -p "Configure Cinnamon [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    CINNAMON_CONFIG_B64="Wy9dCmV4dGVuc2lvbi1jYWNoZS11cGRhdGVkPTE1MzA4MDM1MDAKcGFuZWxzLWF1dG9oaWRlPVsnMTpmYWxzZScsICcyOmludGVsJ10KYWN0aXZlLWRpc3BsYXktc2NhbGU9MQpwYW5lbHMtc2NhbGUtdGV4dC1pY29ucz1bJzE6dHJ1ZScsICcyOnRydWUnXQpwYW5lbHMtaGVpZ2h0PVsnMToyNScsICcyOjUwJ10KcGFuZWxzLXJlc2l6YWJsZT1bJzE6ZmFsc2UnLCAnMjp0cnVlJ10KcGFuZWxzLWhpZGUtZGVsYXk9WycxOjAnLCAnMjowJ10KYWx0dGFiLXN3aXRjaGVyLWRlbGF5PTEwMApjb21tYW5kLWhpc3Rvcnk9WydyJ10KZW5hYmxlZC1hcHBsZXRzPVsncGFuZWwxOnJpZ2h0OjI6c3lzdHJheUBjaW5uYW1vbi5vcmc6MCcsICdwYW5lbDE6bGVmdDo0OnBhbmVsLWxhdW5jaGVyc0BjaW5uYW1vbi5vcmc6MycsICdwYW5lbDE6cmlnaHQ6NDprZXlib2FyZEBjaW5uYW1vbi5vcmc6NScsICdwYW5lbDE6cmlnaHQ6NTpub3RpZmljYXRpb25zQGNpbm5hbW9uLm9yZzo2JywgJ3BhbmVsMTpyaWdodDo2OnJlbW92YWJsZS1kcml2ZXNAY2lubmFtb24ub3JnOjcnLCAncGFuZWwxOnJpZ2h0OjEwOnVzZXJAY2lubmFtb24ub3JnOjgnLCAncGFuZWwxOnJpZ2h0Ojc6bmV0d29ya0BjaW5uYW1vbi5vcmc6OScsICdwYW5lbDE6cmlnaHQ6ODpwb3dlckBjaW5uYW1vbi5vcmc6MTEnLCAncGFuZWwxOmNlbnRlcjowOmNhbGVuZGFyQGNpbm5hbW9uLm9yZzoxMicsICdwYW5lbDE6cmlnaHQ6Mzpzb3VuZEBjaW5uYW1vbi5vcmc6MTMnLCAncGFuZWwxOmxlZnQ6Mzp3aW5kb3dzLXF1aWNrLWxpc3RAY2lubmFtb24ub3JnOjE1JywgJ3BhbmVsMTpyaWdodDoxOndvcmtzcGFjZS1zd2l0Y2hlckBjaW5uYW1vbi5vcmc6MTYnLCAncGFuZWwxOmxlZnQ6MTpDaW5uYW1lbnVAanNvbjoxNycsICdwYW5lbDE6Y2VudGVyOjE6d2VhdGhlckBtb2NrdHVydGw6MTgnLCAncGFuZWwxOmxlZnQ6MDpzcGFjZXJAY2lubmFtb24ub3JnOjIxJywgJ3BhbmVsMTpyaWdodDowOnJlY2VudEBjaW5uYW1vbi5vcmc6MjInLCAncGFuZWwyOmNlbnRlcjowOkljaW5nVGFza01hbmFnZXJAanNvbjoyMyddCndvcmtzcGFjZS1vc2QteD01MAplbmFibGVkLWV4dGVuc2lvbnM9Wyd0cmFuc3BhcmVudC1wYW5lbHNAZ2VybWFuZnInXQpsb29raW5nLWdsYXNzLWhpc3Rvcnk9WydsJ10KbmV4dC1hcHBsZXQtaWQ9MjQKZW5hYmxlZC1kZXNrbGV0cz1AYXMgW10KcGFuZWwtbGF1bmNoZXJzPVsnREVQUkVDQVRFRCddCndvcmtzcGFjZS1vc2QteT01MApwYW5lbC1lZGl0LW1vZGU9ZmFsc2UKd29ya3NwYWNlLWV4cG8tdmlldy1hcy1ncmlkPXRydWUKcGFuZWxzLXNob3ctZGVsYXk9WycxOjAnLCAnMjowJ10Kd29ya3NwYWNlLW9zZC1kdXJhdGlvbj00MDAKZmF2b3JpdGUtYXBwcz1bJ2ZpcmVmb3guZGVza3RvcCcsICdjaW5uYW1vbi1zZXR0aW5ncy5kZXNrdG9wJywgJ3BpZGdpbi5kZXNrdG9wJywgJ29yZy5nbm9tZS5UZXJtaW5hbC5kZXNrdG9wJywgJ25lbW8uZGVza3RvcCcsICd2bXdhcmUtd29ya3N0YXRpb24uZGVza3RvcCddCmFwcGxldC1jYWNoZS11cGRhdGVkPTE1MzA4MDM1NTYKcGFuZWxzLWVuYWJsZWQ9WycxOjA6dG9wJywgJzI6MDpsZWZ0J10KCltzZXR0aW5ncy1kYWVtb24vcGx1Z2lucy9wb3dlcl0KYnV0dG9uLXBvd2VyPSdzaHV0ZG93bicKc2xlZXAtZGlzcGxheS1hYz0zMDAKCltzZXR0aW5ncy1kYWVtb24vcGx1Z2lucy94c2V0dGluZ3NdCm1lbnVzLWhhdmUtaWNvbnM9ZmFsc2UKCltzZXR0aW5ncy1kYWVtb24vcGVyaXBoZXJhbHMva2V5Ym9hcmRdCnJlcGVhdC1pbnRlcnZhbD11aW50MzIgMzAKZGVsYXk9dWludDMyIDUwMApudW1sb2NrLXN0YXRlPSdvbicKClttdWZmaW5dCnJlc2l6ZS10aHJlc2hvbGQ9MjQKd29ya3NwYWNlLWN5Y2xlPXRydWUKd29ya3NwYWNlcy1vbmx5LW9uLXByaW1hcnk9dHJ1ZQoKW2Rlc2t0b3AvaW50ZXJmYWNlXQpjbG9jay1zaG93LWRhdGU9dHJ1ZQpzY2FsaW5nLWZhY3Rvcj11aW50MzIgMApjdXJzb3ItYmxpbmstdGltZT0xMjAwCnRvb2xraXQtYWNjZXNzaWJpbGl0eT1mYWxzZQpjdXJzb3ItdGhlbWU9J21hdGUnCmd0ay10aGVtZT0nQmxhY2tNQVRFJwppY29uLXRoZW1lPSdPYnNpZGlhbi1TYW5kJwoKW2Rlc2t0b3Ava2V5YmluZGluZ3MvY3VzdG9tLWtleWJpbmRpbmdzL2N1c3RvbTBdCmJpbmRpbmc9WydGMTInXQpjb21tYW5kPSd0aWxpeCAtLXF1YWtlJwpuYW1lPSd0aWxpeCBxdWFrZScKCltkZXNrdG9wL2tleWJpbmRpbmdzXQpjdXN0b20tbGlzdD1bJ2N1c3RvbTAnXQoKW2Rlc2t0b3Ava2V5YmluZGluZ3MvbWVkaWEta2V5c10KdGVybWluYWw9WydGYXZvcml0ZXMnXQplbWFpbD1AYXMgW10Kd3d3PVsnTWFpbCddCnNlYXJjaD1bJ1NlYXJjaCddCmhvbWU9WydIb21lUGFnZSddCmNhbGN1bGF0b3I9QGFzIFtdCgpbZGVza3RvcC9rZXliaW5kaW5ncy93bV0Kc3dpdGNoLXRvLXdvcmtzcGFjZS1yaWdodD1bJzxDb250cm9sPjxBbHQ+UmlnaHQnLCAnPFByaW1hcnk+PEFsdD5Eb3duJ10KcHVzaC10aWxlLWRvd249QGFzIFtdCnN3aXRjaC10by13b3Jrc3BhY2UtbGVmdD1bJzxDb250cm9sPjxBbHQ+TGVmdCcsICc8UHJpbWFyeT48QWx0PlVwJ10Kc3dpdGNoLXRvLXdvcmtzcGFjZS1kb3duPVsnPFN1cGVyPkRvd24nXQpwdXNoLXRpbGUtdXA9QGFzIFtdCnN3aXRjaC10by13b3Jrc3BhY2UtdXA9Wyc8U3VwZXI+VXAnLCAnPFN1cGVyPlRhYiddCgpbZGVza3RvcC9tZWRpYS1oYW5kbGluZ10KYXV0b3J1bi14LWNvbnRlbnQtc3RhcnQtYXBwPVsneC1jb250ZW50L3VuaXgtc29mdHdhcmUnLCAneC1jb250ZW50L2Jvb3RhYmxlLW1lZGlhJ10KYXV0b3J1bi1uZXZlcj10cnVlCmF1dG9ydW4teC1jb250ZW50LWlnbm9yZT1bJ3gtY29udGVudC9ib290YWJsZS1tZWRpYSddCmF1dG9ydW4teC1jb250ZW50LW9wZW4tZm9sZGVyPUBhcyBbXQoKW2Rlc2t0b3Avc2NyZWVuc2F2ZXJdCnNob3ctaW5mby1wYW5lbD1mYWxzZQpmbG9hdGluZy13aWRnZXRzPWZhbHNlCnhzY3JlZW5zYXZlci1oYWNrPSd1bmtub3ducGxlYXN1cmVzJwpsb2NrLWRlbGF5PXVpbnQzMiAxNQpzaG93LWNsb2NrPWZhbHNlCmFsbG93LWtleWJvYXJkLXNob3J0Y3V0cz1mYWxzZQphbGxvdy1tZWRpYS1jb250cm9sPWZhbHNlCnNjcmVlbnNhdmVyLW5hbWU9JycKc2hvdy1hbGJ1bS1hcnQ9ZmFsc2UKCltkZXNrdG9wL2FwcGxpY2F0aW9ucy90ZXJtaW5hbF0KZXhlYz0ndGlsaXgnCgpbZGVza3RvcC9ub3RpZmljYXRpb25zXQpmYWRlLW9wYWNpdHk9NDAKCltkZXNrdG9wL3Nlc3Npb25dCmlkbGUtZGVsYXk9dWludDMyIDAKCltkZXNrdG9wL3ByaXZhY3ldCnJlY2VudC1maWxlcy1tYXgtYWdlPS0xCgpbZGVza3RvcC93bS9wcmVmZXJlbmNlc10KbWluLXdpbmRvdy1vcGFjaXR5PTMwCm1vdXNlLWJ1dHRvbi1tb2RpZmllcj0nPFN1cGVyPicKdGhlbWU9J051bWl4JwoKW2Rlc2t0b3AvYTExeS9hcHBsaWNhdGlvbnNdCnNjcmVlbi1rZXlib2FyZC1lbmFibGVkPWZhbHNlCnNjcmVlbi1yZWFkZXItZW5hYmxlZD1mYWxzZQoKW2Rlc2t0b3AvYTExeS9rZXlib2FyZF0Kc2xvd2tleXMtYmVlcC1wcmVzcz10cnVlCm1vdXNla2V5cy1hY2NlbC10aW1lPTEyMDAKYm91bmNla2V5cy1iZWVwLXJlamVjdD10cnVlCnNsb3drZXlzLWJlZXAtcmVqZWN0PWZhbHNlCmRpc2FibGUtdGltZW91dD0xMjAKZW5hYmxlPWZhbHNlCmJvdW5jZWtleXMtZW5hYmxlPWZhbHNlCnN0aWNreWtleXMtZW5hYmxlPWZhbHNlCmZlYXR1cmUtc3RhdGUtY2hhbmdlLWJlZXA9ZmFsc2UKc2xvd2tleXMtYmVlcC1hY2NlcHQ9dHJ1ZQpib3VuY2VrZXlzLWRlbGF5PTMwMAptb3VzZWtleXMtbWF4LXNwZWVkPTc1MAptb3VzZWtleXMtZW5hYmxlPWZhbHNlCnRpbWVvdXQtZW5hYmxlPWZhbHNlCnNsb3drZXlzLWRlbGF5PTMwMApzdGlja3lrZXlzLW1vZGlmaWVyLWJlZXA9dHJ1ZQpzdGlja3lrZXlzLXR3by1rZXktb2ZmPXRydWUKbW91c2VrZXlzLWluaXQtZGVsYXk9MTYwCnNsb3drZXlzLWVuYWJsZT1mYWxzZQoKW2Rlc2t0b3AvYTExeS9tb3VzZV0Kc2Vjb25kYXJ5LWNsaWNrLWVuYWJsZWQ9ZmFsc2UKc2Vjb25kYXJ5LWNsaWNrLXRpbWU9MS4yCmR3ZWxsLXRpbWU9MS4yCmR3ZWxsLXRocmVzaG9sZD0xMApkd2VsbC1jbGljay1lbmFibGVkPWZhbHNlCgpbZGVza3RvcC9zb3VuZF0KZXZlbnQtc291bmRzPWZhbHNlCgpbY2lubmFtb24tc2Vzc2lvbl0KcXVpdC10aW1lLWRlbGF5PTYwCgpbdGhlbWVdCnRoZW1lLWNhY2hlLXVwZGF0ZWQ9MTUyNTM2NzQ3Nwo="
    echo "$CINNAMON_CONFIG_B64" | base64 -d > /tmp/cinnsetup.dconf
    dconf load /org/cinnamon/ < /tmp/cinnsetup.dconf
    rm -f /tmp/cinnsetup.dconf
  fi

  unset CONFIRMATION
  read -p "Configure Tilix [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    TILIX_CONFIG_B64="Wy9dCndhcm4tdnRlLWNvbmZpZy1pc3N1ZT1mYWxzZQpzaWRlYmFyLW9uLXJpZ2h0PXRydWUKCltrZXliaW5kaW5nc10Kd2luLXZpZXctc2lkZWJhcj0nTWVudScKCltwcm9maWxlcy8yYjdjNDA4MC0wZGRkLTQ2YzUtOGYyMy01NjNmZDNiYTc4OWRdCmZvcmVncm91bmQtY29sb3I9JyNGOEY4RjInCnZpc2libGUtbmFtZT0nRGVmYXVsdCcKcGFsZXR0ZT1bJyMyNzI4MjInLCAnI0Y5MjY3MicsICcjQTZFMjJFJywgJyNGNEJGNzUnLCAnIzY2RDlFRicsICcjQUU4MUZGJywgJyNBMUVGRTQnLCAnI0Y4RjhGMicsICcjNzU3MTVFJywgJyNGOTI2NzInLCAnI0E2RTIyRScsICcjRjRCRjc1JywgJyM2NkQ5RUYnLCAnI0FFODFGRicsICcjQTFFRkU0JywgJyNGOUY4RjUnXQpiYWRnZS1jb2xvci1zZXQ9ZmFsc2UKdXNlLXN5c3RlbS1mb250PWZhbHNlCmN1cnNvci1jb2xvcnMtc2V0PWZhbHNlCmhpZ2hsaWdodC1jb2xvcnMtc2V0PWZhbHNlCnVzZS10aGVtZS1jb2xvcnM9ZmFsc2UKYm9sZC1jb2xvci1zZXQ9ZmFsc2UKZm9udD0nSGFjayAxMicKdGVybWluYWwtYmVsbD0nbm9uZScKYmFja2dyb3VuZC1jb2xvcj0nIzI3MjgyMicK"
    echo "$TILIX_CONFIG_B64" | base64 -d > /tmp/tilixsetup.dconf
    dconf load /com/gexperts/Tilix/ < /tmp/tilixsetup.dconf
    rm -f /tmp/tilixsetup.dconf
  fi

  unset CONFIRMATION
  read -p "Setup user-dirs.dirs [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    cat <<EOT > ~/.config/user-dirs.dirs
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/download"
XDG_TEMPLATES_DIR="$HOME/Documents/Templates"
XDG_PUBLICSHARE_DIR="$HOME/tmp"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/media/music"
XDG_PICTURES_DIR="$HOME/media/video"
XDG_VIDEOS_DIR="$HOME/media/images"
EOT
  fi

fi
