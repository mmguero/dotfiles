#!/usr/bin/env bash

# my one-stop-shopping Linux box setup.
# tested in Debian Linux and sort-of on macOS.
# if you are not me, this might not be what you want.

export DEBIAN_FRONTEND=noninteractive

ENV_LIST=(
  pyenv
  rbenv
  goenv
  nodenv
  plenv
)

# empty arrays will be populated with most recent available versions at runtime
PYTHON_VERSIONS=( )
RUBY_VERSIONS=( )
GOLANG_VERSIONS=( )
NODEJS_VERSIONS=( )
PERL_VERSIONS=( 5.30.0 )
DOCKER_COMPOSE_INSTALL_VERSION=( 1.24.1 )

# add contents of https://raw.githubusercontent.com/mmguero/config/master/bash/rc.d/04_envs.bashrc
# to .bashrc after running this script (or let this script set up the symlinks for ~/.bashrc.d for you)

if [ -z "$BASH_VERSION" ]; then
  echo "Wrong interpreter, please run \"$0\" with bash"
  exit 1
fi

[[ "$(uname -s)" = 'Darwin' ]] && REALPATH=grealpath || REALPATH=realpath
[[ "$(uname -s)" = 'Darwin' ]] && DIRNAME=gdirname || DIRNAME=dirname
if ! (type "$REALPATH" && type "$DIRNAME") > /dev/null; then
  echo "$(basename "${BASH_SOURCE[0]}") requires $REALPATH and $DIRNAME"
  exit 1
fi
SCRIPT_PATH="$($DIRNAME $($REALPATH -e "${BASH_SOURCE[0]}"))"

# see if this has been cloned from github (so we can assume other stuff might be here)
unset GUERO_GITHUB_PATH
if [ $(basename "$SCRIPT_PATH") = 'bash' ]; then
  pushd "$SCRIPT_PATH"/.. >/dev/null 2>&1
  if (( "$( (git remote -v 2>/dev/null | awk '{print $2}' | grep -P 'config(_private)?' | wc -l) || echo 0 )" > 0 )); then
    GUERO_GITHUB_PATH="$(pwd)"
  fi
  popd >/dev/null 2>&1
fi

# determine OS
unset MACOS
unset LINUX
unset WINDOWS
unset LINUX_DISTRO
unset LINUX_RELEASE

if [ $(uname -s) = 'Darwin' ]; then
  export MACOS=0

elif grep -q Microsoft /proc/version; then
  export WINDOWS=0
  echo "Windows is not currently supported by this script."
  exit 1

else
  export LINUX=0
  if command -v lsb_release >/dev/null 2>&1 ; then
    LINUX_DISTRO="$(lsb_release -is)"
    LINUX_RELEASE="$(lsb_release -cs)"
  else
    if [[ -r '/etc/redhat-release' ]]; then
      RELEASE_FILE='/etc/redhat-release'
    elif [[ -r '/etc/issue' ]]; then
      RELEASE_FILE='/etc/issue'
    else
      unset RELEASE_FILE
    fi
    [[ -n "$RELEASE_FILE" ]] && LINUX_DISTRO="$( ( awk '{print $1}' < "$RELEASE_FILE" ) | head -n 1 )"
  fi
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
  if ! dpkg -s apt >/dev/null 2>&1; then
    echo "This command only target Linux distributions that use apt/apt-get"
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
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y curl git
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

  # alternately they may be set up individually

  if [ -z "$PYENV_ROOT" ] && [ -d ~/.pyenv ]; then
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
  fi

  if [ -z "$RBENV_ROOT" ] && [ -d ~/.rbenv ]; then
    export RBENV_ROOT="$HOME/.rbenv"
    [[ -d $RBENV_ROOT/bin ]] && PATH="$RBENV_ROOT/bin:$PATH"
    eval "$(rbenv init -)"
  fi

  if [ -z "$GOENV_ROOT" ] && [ -d ~/.goenv ]; then
    export GOENV_ROOT="$HOME/.goenv"
    [[ -d $GOENV_ROOT/bin ]] && PATH="$GOENV_ROOT/bin:$PATH"
    eval "$(goenv init -)"
  fi

  if [ -z "$NODENV_ROOT" ] && [ -d ~/.nodenv ]; then
    export NODENV_ROOT="$HOME/.nodenv"
    [[ -d $NODENV_ROOT/bin ]] && PATH="$NODENV_ROOT/bin:$PATH"
    eval "$(nodenv init -)"
  fi

  if [ -z "$PLENV_ROOT" ] && [ -d ~/.plenv ]; then
    export PLENV_ROOT="$HOME/.plenv"
    [[ -d $PLENV_ROOT/bin ]] && PATH="$PLENV_ROOT/bin:$PATH"
    eval "$(plenv init -)"
  fi

  # once we've sourced things for paths, set up any other custom stuf the envs need

  if [ $PYENV_ROOT ]; then
    [[ -r $PYENV_ROOT/completions/pyenv.bash ]] && . $PYENV_ROOT/completions/pyenv.bash
    [[ -d $PYENV_ROOT/plugins/pyenv-virtualenv ]] && eval "$(pyenv virtualenv-init -)"
  fi

  if [ $GOENV_ROOT ]; then
    export GOROOT="$(goenv prefix)"
  fi
  export GOPATH=$DEVEL_ROOT/gopath
  [[ -d $GOPATH/bin ]] && PATH="$GOPATH/bin:$PATH"
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

  brew cask list >/dev/null 2>&1
  brew tap caskroom/versions

fi # MacOS check

InstallCurlAndGit

################################################################################
# envs (mac via brew, linux via anyenv)
################################################################################
declare -A ENVS_INSTALLED
for i in ${ENV_LIST[@]}; do
  ENVS_INSTALLED[$i]=false
done

# install env manager(s)
if [ $MACOS ]; then

  for i in ${ENV_LIST[@]}; do
    if ! brew ls --versions "$i" >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "\"$i\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        brew install $i && ENVS_INSTALLED[$i]=true
      fi
    fi
  done

elif [ $LINUX ]; then

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
    anyenv update
    for i in ${ENV_LIST[@]}; do
      if ! ( anyenv envs | grep -q "$i" ) >/dev/null 2>&1 ; then
        unset CONFIRMATION
        read -p "\"$i\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          anyenv install "$i" && ENVS_INSTALLED[$i]=true
        fi
      else
        unset CONFIRMATION
        read -p "\"$i\" is already installed, attempt to update it [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          ENVS_INSTALLED[$i]=true
        fi
      fi
    done
  fi
fi
EnvSetup

# install versions of the tools and plugins

# python
if [ -n $PYENV_ROOT ] && [ ${ENVS_INSTALLED[pyenv]} = 'true' ]; then
  if [ $LINUX ]; then
    DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
      build-essential \
      libbz2-dev \
      libffi-dev \
      libfreetype6-dev \
      libfribidi-dev \
      libharfbuzz-dev \
      libjpeg-dev \
      liblcms2-dev \
      libncurses5-dev \
      libopenjp2-7-dev \
      libreadline-dev \
      libsqlite3-dev \
      libssl-dev \
      libtiff5-dev \
      libwebp-dev \
      libxml2-dev \
      libxmlsec1-dev \
      llvm \
      make \
      python-tk \
      tcl8.6-dev \
      tk-dev \
      tk8.6-dev \
      wget \
      xz-utils \
      zlib1g-dev
  fi
  # make the second 3 to 2 for py2  V
  for MAJOR_VER in $(seq -s' ' 3 -1 3); do
    PY_VER="$(pyenv install --list | awk '{print $1}' | grep ^$MAJOR_VER | grep -v - | grep -Pv "(b(eta)?|rc)\d*$" | tail -1)"
    [[ -n $PY_VER ]] && PYTHON_VERSIONS+=($PY_VER)
  done
  for ver in "${PYTHON_VERSIONS[@]}"; do
    pyenv install "$ver"
  done
  pyenv global "${PYTHON_VERSIONS[@]}"
  mkdir -p "$(pyenv root)"/plugins/
  git clone https://github.com/pyenv/pyenv-update.git "$(pyenv root)"/plugins/pyenv-update
  git clone https://github.com/pyenv/pyenv-virtualenv.git "$(pyenv root)"/plugins/pyenv-virtualenv
  if [ ! -d "$(pyenv root)"/bin ] && [ -d "$(pyenv root)"/shims ]; then
    pushd "$(pyenv root)"
    ln -s ./shims ./bin
    popd
  fi
fi

# ruby
if [ -n $RBENV_ROOT ] && [ ${ENVS_INSTALLED[rbenv]} = 'true' ]; then
  RB_VER="$(rbenv install --list | awk '{print $1}' | grep -v - | grep -Pv "(b(eta)?|rc)\d*$" | tail -1)"
  [[ -n $RB_VER ]] && RUBY_VERSIONS+=($RB_VER)
  for ver in "${RUBY_VERSIONS[@]}"; do
    rbenv install "$ver"
  done
  rbenv global "${RUBY_VERSIONS[@]}"
  mkdir -p "$(rbenv root)"/plugins/
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
  git clone https://github.com/rkh/rbenv-update.git "$(rbenv root)"/plugins/rbenv-update
  if [ ! -d "$(rbenv root)"/bin ] && [ -d "$(rbenv root)"/shims ]; then
    pushd "$(rbenv root)"
    ln -s ./shims ./bin
    popd
  fi
fi

# golang
if [ -n $GOENV_ROOT ] && [ ${ENVS_INSTALLED[goenv]} = 'true' ]; then
  GO_VER="$(goenv install --list | awk '{print $1}' | grep -v - | grep -Pv "(b(eta)?|rc)\d*$" | tail -1)"
  [[ -n $GO_VER ]] && GOLANG_VERSIONS+=($GO_VER)
  for ver in "${GOLANG_VERSIONS[@]}"; do
    goenv install "$ver"
  done
  goenv global "${GOLANG_VERSIONS[@]}"
  mkdir -p "$(goenv root)"/plugins/
  git clone https://github.com/trafficgate/goenv-install-glide.git "$(goenv root)"/plugins/goenv-install-glide
  if [ ! -d "$(goenv root)"/bin ] && [ -d "$(goenv root)"/shims ]; then
    pushd "$(goenv root)"
    ln -s ./shims ./bin
    popd
  fi
fi

# nodejs
if [ -n $NODENV_ROOT ] && [ ${ENVS_INSTALLED[nodenv]} = 'true' ]; then
  NODE_VER="$(nodenv install --list | awk '{print $1}' | grep -v - | grep -Pv "(b(eta)?|rc)\d*$" | tail -1)"
  [[ -n $NODE_VER ]] && NODEJS_VERSIONS+=($NODE_VER)
  for ver in "${NODEJS_VERSIONS[@]}"; do
    nodenv install "$ver"
  done
  nodenv global "${NODEJS_VERSIONS[@]}"
  mkdir -p "$(nodenv root)"/plugins/
  git clone https://github.com/nodenv/node-build.git "$(nodenv root)"/plugins/node-build
  git clone https://github.com/nodenv/nodenv-update.git "$(nodenv root)"/plugins/nodenv-update
  if [ ! -d "$(nodenv root)"/bin ] && [ -d "$(nodenv root)"/shims ]; then
    pushd "$(nodenv root)"
    ln -s ./shims ./bin
    popd
  fi
fi

# perl
if [ -n $PLENV_ROOT ] && [ ${ENVS_INSTALLED[plenv]} = 'true' ]; then
  for ver in "${PERL_VERSIONS[@]}"; do
    plenv install "$ver"
  done
  plenv global "${PERL_VERSIONS[@]}"
  mkdir -p "$(plenv root)"/plugins/
  if [ ! -d "$(plenv root)"/bin ] && [ -d "$(plenv root)"/shims ]; then
    pushd "$(plenv root)"
    ln -s ./shims ./bin
    popd
  fi
fi

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
      beautifulsoup4 \
      colored \
      cryptography \
      Cython \
      entrypoint2 \
      git+git://github.com/badele/gitcheck.git \
      git-up \
      ordered-set \
      patool \
      Pillow \
      psutil \
      pyinotify \
      pythondialog \
      python-magic \
      pyshark \
      pyunpack \
      pyyaml \
      requests\[security\] \
      scapy \
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
# apt repositories
################################################################################

# enable contrib and non-free in sources.list
if [[ -n $LINUX ]] && [[ -n $LINUX_RELEASE ]]; then

  if [[ -f /etc/apt/sources.list ]] && (( "$(grep -cP "(contrib|non-free)" /etc/apt/sources.list)" == 0 )); then
    unset CONFIRMATION
    read -p "Enable contrib and non-free for $LINUX_RELEASE in /etc/apt/sources.list [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD sed -i "s/$LINUX_RELEASE main/$LINUX_RELEASE main contrib non-free/" /etc/apt/sources.list
    fi
  fi

  # sources.list.d entries for this release
  if [[ -n $GUERO_GITHUB_PATH ]] && [[ -d /etc/apt/sources.list.d ]] && [[ -d "$GUERO_GITHUB_PATH/linux/apt/sources.list.d/$LINUX_RELEASE" ]]; then
    unset CONFIRMATION
    read -p "Install sources.list.d entries for $LINUX_RELEASE [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD cp -iv "$GUERO_GITHUB_PATH/linux/apt/sources.list.d/$LINUX_RELEASE"/* /etc/apt/sources.list.d/
      # pull GPG keys from keyserver.ubuntu.com and update the apt cache
      $SUDO_CMD apt-get update 2>&1 | grep -Po "NO_PUBKEY\s*\w+" | awk '{print $2}' | sort -u | xargs -r -l $SUDO_CMD apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    fi
  fi

fi

################################################################################
# docker
################################################################################
if [ $MACOS ]; then

  # install docker-edge, if needed
  if ! brew cask ls --versions docker-edge >/dev/null 2>&1 ; then
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

      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
                                                 apt-transport-https \
                                                 ca-certificates \
                                                 curl \
                                                 gnupg2 \
                                                 software-properties-common

      curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO_CMD apt-key add -

      echo "Installing Docker CE..."

      if [[ "$LINUX_DISTRO" == "Ubuntu" ]]; then
        $SUDO_CMD add-apt-repository \
           "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
           $(lsb_release -cs) \
           stable"
      elif [[ "$LINUX_DISTRO" == "Debian" ]]; then
        $SUDO_CMD add-apt-repository \
           "deb [arch=amd64] https://download.docker.com/linux/debian \
           $(lsb_release -cs) \
           stable"
      fi

      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y docker-ce

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
        pip install -U docker-compose
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

if $SUDO_CMD docker info >/dev/null 2>&1 ; then
  unset CONFIRMATION
  read -p "Pull common docker images [y/N]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-N}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    DOCKER_IMAGES=(
      alpine:latest
      debian:stable-slim
      debian:testing-slim
      hello-world:latest
      ubuntu:latest
    )
    for i in ${DOCKER_IMAGES[@]}; do
      docker pull "$i"
    done
  fi # docker pull images confirmation
fi # docker is there

################################################################################
# virtualbox/vagrant
################################################################################
if [ $MACOS ]; then

  # install virtualbox, if needed
  if ! brew cask ls --versions virtualbox >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "\"virtualbox\" cask is not installed, attempt to install virtualbox via brew [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      echo "Installing virtualbox..."
      brew cask install virtualbox
      echo "Installed virtualbox."
    fi # virtualbox install confirmation check
  else
    echo "\"virtualbox\" is already installed!"
  fi # virtualbox install check

  # install Vagrant only if vagrant is not yet installed and virtualbox is now installed
  if ! brew cask ls --versions vagrant >/dev/null 2>&1 && brew cask ls --versions virtualbox >/dev/null 2>&1; then
    unset CONFIRMATION
    read -p "\"vagrant\" cask is not installed, attempt to install vagrant via brew [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      echo "Installing vagrant..."
      brew cask install vagrant
      echo "Installed vagrant."
    fi # vagrant install confirmation check
  fi

  # install vagrant-manager only if vagrant is installed
  if ! brew cask ls --versions vagrant-manager >/dev/null 2>&1 && brew cask ls --versions vagrant >/dev/null 2>&1; then
    unset CONFIRMATION
    read -p "\"vagrant-manager\" cask is not installed, attempt to install vagrant-manager via brew [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      echo "Installing vagrant-manager..."
      brew cask install vagrant-manager
      echo "Installed vagrant-manager."
    fi # vagrant-manager install confirmation check
  fi

elif [ $LINUX ]; then

  # virtualbox (if not already installed)
  $SUDO_CMD apt-get update -qq >/dev/null 2>&1

  if ! command -v VBoxManage >/dev/null 2>&1 ; then
    unset VBOX_PACKAGE_NAME
    VBOX_PACKAGE_NAMES=(
      virtualbox-6.0
      virtualbox
      virtualbox-5.2
    )
    for i in ${VBOX_PACKAGE_NAMES[@]}; do
      VBOX_CANDIDATE="$(apt-cache policy "$i" | grep Candidate: | awk '{print $2}' | grep -v '(none)')"
      if [[ -n $VBOX_CANDIDATE ]]; then
        VBOX_PACKAGE_NAME=$i
        break
      fi
    done
    if [[ -n $VBOX_PACKAGE_NAME ]]; then
      unset CONFIRMATION
      read -p "Install $VBOX_PACKAGE_NAME [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y dkms module-assistant linux-headers-$(uname -r) "$VBOX_PACKAGE_NAME"
        if [[ "$SCRIPT_USER" != "root" ]]; then
          echo "Adding \"$SCRIPT_USER\" to group \"vboxusers\"..."
          $SUDO_CMD usermod -a -G vboxusers "$SCRIPT_USER"
          echo "You will need to log out and log back in for this to take effect"
        fi
      fi

      # virtualbox extension pack
      VBOX_EXTPACK_URL="$(curl -fsL "https://www.virtualbox.org/wiki/Downloads" | grep -oP "https://.*?vbox-extpack" | sort -V | head -n 1)"
      unset CONFIRMATION
      read -p "Download and install $VBOX_EXTPACK_URL [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        VBOX_EXTPACK_FNAME="$(echo "$VBOX_EXTPACK_URL" | sed "s@.*/@@")"
        pushd /tmp >/dev/null 2>&1
        curl -L -J -O "$VBOX_EXTPACK_URL"
        if [[ -r "$VBOX_EXTPACK_FNAME" ]]; then
          $SUDO_CMD VBoxManage extpack install --accept-license=56be48f923303c8cababb0bb4c478284b688ed23f16d775d729b89a2e8e5f9eb --replace "$VBOX_EXTPACK_FNAME"
        else
          echo "Error downloading $VBOX_EXTPACK_URL to $VBOX_EXTPACK_FNAME"
        fi
        popd >/dev/null 2>&1
      fi

    fi
  else
    echo "\"virtualbox\" is already installed!"
  fi # check VBoxManage is not in path to see if some form of virtualbox is already installed

  # install Vagrant only if vagrant is not yet installed and virtualbox is now installed
  if ! command -v vagrant >/dev/null 2>&1; then
    unset CONFIRMATION
    read -p "Attempt to download and install latest version of Vagrant from releases.hashicorp.com [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      curl -o /tmp/vagrant.deb "https://releases.hashicorp.com$(curl -fsL "https://releases.hashicorp.com$(curl -fsL "https://releases.hashicorp.com/vagrant" | grep 'href="/vagrant/' | head -n 1 | grep -o '".*"' | tr -d '"' )" | grep "x86_64\.deb" | head -n 1 | grep -o 'href=".*"' | sed 's/href=//' | tr -d '"')"
      $SUDO_CMD dpkg -i /tmp/vagrant.deb
      rm -f /tmp/vagrant.deb
    else
      unset CONFIRMATION
      read -p "Install vagrant via apt-get instead [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      [[ $CONFIRMATION =~ ^[Yy] ]] && DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y vagrant
    fi
  else
    echo "\"vagrant\" is already installed!"
  fi # check vagrant is already installed

fi # MacOS vs. Linux for virtualbox/vagrant

# see if we want to install vagrant plugins
if command -v vagrant >/dev/null 2>&1; then
  unset CONFIRMATION
  read -p "Install/update common vagrant plugins [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    VAGRANT_PLUGINS=(
      vagrant-reload
      vagrant-scp
      vagrant-sshfs
      vagrant-vbguest
    )
    for i in ${VAGRANT_PLUGINS[@]}; do
      if (( "$( vagrant plugin list | grep -c "^$i " )" == 0 )); then
        vagrant plugin install $i
      fi
    done
    vagrant plugin update all
  fi # vagrant plugin install confirmation

  unset CONFIRMATION
  read -p "Install common vagrant boxes [y/N]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-N}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    VAGRANT_BOXES=(
      bento/centos-8
      bento/debian-10
      bento/fedora-31
      bento/ubuntu-19.10
    )
    for i in ${VAGRANT_BOXES[@]}; do
      if (( "$( vagrant box list | grep -c "^$i " )" == 0 )); then
        vagrant box add --provider virtualbox $i
      fi
    done
    vagrant box outdated --global | grep "is outdated" | awk '{print $2}' | xargs -r -l vagrant box update --provider virtualbox --box
    vagrant box prune --provider virtualbox
  fi # vagrant plugin install confirmation

fi # check for vagrant being installed

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
    brew install tmux
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
      apt-file
      apt-listchanges
      apt-show-versions
      apt-transport-https
      apt-utils
      autoconf
      automake
      bash
      binutils
      bison
      btrfs-progs
      build-essential
      bzip2
      ca-certificates
      cgdb
      checkinstall
      cloc
      cmake
      coreutils
      cpio
      cryptmount
      cryptsetup
      dialog
      diffutils
      eject
      exfat-fuse
      exfat-utils
      fdisk
      file
      findutils
      firmware-amd-graphics
      firmware-iwlwifi
      firmware-linux
      firmware-linux-free
      firmware-linux-nonfree
      firmware-misc-nonfree
      flex
      fonts-hack
      fonts-hack-ttf
      fuse
      fuseext2
      fusefat
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
      less
      libcap2-bin
      linux-headers-$(uname -r)
      localepurge
      lshw
      lsof
      make
      moreutils
      ninja-build
      ntfs-3g
      openssl
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
      sed
      strace
      sysstat
      time
      tmux
      tofrodos
      tree
      tzdata
      ufw
      unrar
      unzip
      vim-tiny
      zlib1g
    )

    # preseed some packages for setup post-installation
    cat <<EOT >> /tmp/localepurge-preseed.cfg
localepurge localepurge/nopurge multiselect en, en_US, en_us.UTF-8, C.UTF-8
localepurge localepurge/use-dpkg-feature boolean true
localepurge localepurge/none_selected boolean false
localepurge localepurge/verbose boolean false
localepurge localepurge/dontbothernew boolean false
localepurge localepurge/quickndirtycalc boolean true
localepurge localepurge/mandelete boolean true
localepurge localepurge/showfreedspace boolean false
localepurge localepurge/remove_no note
EOT
    $SUDO_CMD debconf-set-selections -v /tmp/localepurge-preseed.cfg
    echo "wireshark-common wireshark-common/install-setuid boolean false" | $SUDO_CMD debconf-set-selections

    # install the packages
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done

    # pre-install configurations
    $SUDO_CMD groupadd fuse
    $SUDO_CMD groupadd cryptkeeper

    if dpkg -s localepurge >/dev/null 2>&1 ; then
      $SUDO_CMD dpkg-reconfigure --frontend=noninteractive localepurge
      $SUDO_CMD localepurge
      rm -f /tmp/localepurge-preseed.cfg
    fi

    $SUDO_CMD dpkg-reconfigure --frontend=noninteractive wireshark-common
    if ! grep -q mapper /etc/pmount.allow; then
      $SUDO_CMD tee -a /etc/pmount.allow > /dev/null <<'EOT'

# mountpoints for luks volumes
/dev/mapper/tc1
/dev/mapper/tc2
/dev/mapper/tc3
/dev/mapper/tc4
/dev/mapper/tc5
/dev/mapper/tc6
/dev/mapper/tc7
/dev/mapper/tc8
/dev/mapper/tc9
EOT
    fi

  fi # install common packages confirmation

  unset CONFIRMATION
  read -p "Install common packages (GUI) [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    DEBIAN_PACKAGE_LIST=(
      albert
      arandr
      dconf-cli
      fonts-hack
      ghex
      gparted
      gtk2-engines-murrine
      gtk2-engines-pixbuf
      keepassxc
      meld
      numix-gtk-theme
      obsidian-icon-theme
      regexxer
      sublime-text
      thunar
      thunar-archive-plugin
      thunar-volman
      tilix
      ttf-mscorefonts-installer
      wireshark
      x2goclient
      xdiskusage
      xfdesktop4
      xxdiff
      xxdiff-scripts
      zenmap
    )
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done

    if [ ! -d ~/.themes/vimix-dark-laptop-beryl ]; then
      TMP_CLONE_DIR="$(mktemp -d)"
      git clone --depth 1 https://github.com/vinceliuice/vimix-gtk-themes "$TMP_CLONE_DIR"
      pushd "$TMP_CLONE_DIR" >/dev/null 2>&1
      mkdir -p ~/.themes
      ./Install -d ~/.themes -n vimix -c dark -t beryl -s laptop
      popd >/dev/null 2>&1
      rm -rf "$TMP_CLONE_DIR"
    fi

  fi

  unset CONFIRMATION
  read -p "Install common packages (media) [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    DEBIAN_PACKAGE_LIST=(
      audacious
      audacity
      ffmpeg
      gimp
      gimp-plugin-registry
      gimp-texturize
      gtk-recordmydesktop
      imagemagick
      mpv
      pavucontrol
      pithos
      recordmydesktop
      wodim
    )
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done
    if pip -V >/dev/null 2>&1 ; then
      pip install -U youtube-dl
    fi
  fi

  unset CONFIRMATION
  read -p "Install common packages (networking) [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    DEBIAN_PACKAGE_LIST=(
      apache2-utils
      autossh
      bridge-utils
      bro
      bro-aux
      cifs-utils
      cryptcat
      curl
      dnsutils
      dsniff
      ethtool
      iproute2
      mosh
      ncat
      netsniff-ng
      ngrep
      nmap
      openresolv
      openssh-client
      openvpn
      rsync
      socat
      sshfs
      ssldump
      tcpdump
      telnet
      traceroute
      tshark
      wget
      whois
    )
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done

    curl -o /tmp/firefox.tar.bz2 -L "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US"
    if [ $(file -b --mime-type /tmp/firefox.tar.bz2) = 'application/x-bzip2' ]; then
      $SUDO_CMD mkdir -p /opt
      $SUDO_CMD rm -rvf /opt/firefox
      $SUDO_CMD tar -xvf /tmp/firefox.tar.bz2 -C /opt/
      rm -vf /tmp/firefox.tar.bz2
      if [[ -f /opt/firefox/firefox ]]; then
        $SUDO_CMD rm -vf /usr/local/bin/firefox
        $SUDO_CMD ln -vrs /opt/firefox/firefox /usr/local/bin/firefox
        $SUDO_CMD tee /usr/share/applications/firefox.desktop > /dev/null <<'EOT'
[Desktop Entry]
Name=Firefox
Comment=Web Browser
GenericName=Web Browser
X-GNOME-FullName=Firefox Web Browser
Exec=/opt/firefox/firefox %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=/opt/firefox/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=Firefox
StartupNotify=true
EOT
        dpkg -s firefox-esr >/dev/null 2>&1 && $SUDO_CMD apt-get -y --purge remove firefox-esr
      fi
    fi # /tmp/firefox.tar.bz2 check

  fi

  unset CONFIRMATION
  read -p "Install common packages (forensics/security) [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    DEBIAN_PACKAGE_LIST=(
      forensics-all
      android-tools-adb
      android-tools-fastboot
      autopsy
      bcrypt
      blktool
      chntpw
      clamav
      clamav-freshclam
      cmospwd
      crack
      darkstat
      dcfldd
      discover
      disktype
      ettercap-graphical
      ewf-tools
      exif
      exiftags
      ext3grep
      fbi
      foremost
      gddrescue
      gpart
      guymager
      hunt
      hydra-gtk
      john
      john-data
      knocker
      libafflib0v5
      libewf2
      libguytools2
      lshw
      nast
      nasty
      nikto
      p0f
      plaso
      rekall-core
      safecat
      scsitools
      stenographer
      stenographer-client
      testdisk
      weplab
    )
    for i in ${DEBIAN_PACKAGE_LIST[@]}; do
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
    done
  fi

  unset CONFIRMATION
  read -p "Create missing common local config in home [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then

    touch ~/.hushlogin

    mkdir -p "$HOME/Desktop" "$HOME/download" "$HOME/media/music" "$HOME/media/images" "$HOME/media/video" "$HOME/tmp" "$HOME/.local/bin"

    [ ! -f ~/.vimrc ] && echo "set nocompatible" > ~/.vimrc

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

    dpkg -s thunar >/dev/null 2>&1 && xdg-mime default Thunar-folder-handler.desktop inode/directory application/x-gnome-saved-search
  fi

  if dpkg -s tilix >/dev/null 2>&1; then
    unset CONFIRMATION
    read -p "Configure Tilix [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      TILIX_CONFIG_B64="Wy9dCndhcm4tdnRlLWNvbmZpZy1pc3N1ZT1mYWxzZQpzaWRlYmFyLW9uLXJpZ2h0PXRydWUKCltrZXliaW5kaW5nc10Kd2luLXZpZXctc2lkZWJhcj0nTWVudScKCltwcm9maWxlcy8yYjdjNDA4MC0wZGRkLTQ2YzUtOGYyMy01NjNmZDNiYTc4OWRdCmZvcmVncm91bmQtY29sb3I9JyNGOEY4RjInCnZpc2libGUtbmFtZT0nRGVmYXVsdCcKcGFsZXR0ZT1bJyMyNzI4MjInLCAnI0Y5MjY3MicsICcjQTZFMjJFJywgJyNGNEJGNzUnLCAnIzY2RDlFRicsICcjQUU4MUZGJywgJyNBMUVGRTQnLCAnI0Y4RjhGMicsICcjNzU3MTVFJywgJyNGOTI2NzInLCAnI0E2RTIyRScsICcjRjRCRjc1JywgJyM2NkQ5RUYnLCAnI0FFODFGRicsICcjQTFFRkU0JywgJyNGOUY4RjUnXQpiYWRnZS1jb2xvci1zZXQ9ZmFsc2UKdXNlLXN5c3RlbS1mb250PWZhbHNlCmN1cnNvci1jb2xvcnMtc2V0PWZhbHNlCmhpZ2hsaWdodC1jb2xvcnMtc2V0PWZhbHNlCnVzZS10aGVtZS1jb2xvcnM9ZmFsc2UKYm9sZC1jb2xvci1zZXQ9ZmFsc2UKZm9udD0nSGFjayAxMicKdGVybWluYWwtYmVsbD0nbm9uZScKYmFja2dyb3VuZC1jb2xvcj0nIzI3MjgyMicK"
      echo "$TILIX_CONFIG_B64" | base64 -d > /tmp/tilixsetup.dconf
      dconf load /com/gexperts/Tilix/ < /tmp/tilixsetup.dconf
      rm -f /tmp/tilixsetup.dconf
    fi
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

  if [[ "$SCRIPT_USER" != "root" ]]; then

    # give unlimited, godlike power
    unset CONFIRMATION
    read -p "Add $SCRIPT_USER to godlike groups [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      POWER_GROUPS=(
        adm
        bluetooth
        audio
        cdrom
        cryptkeeper
        disk
        docker
        fuse
        lpadmin
        netdev
        plugdev
        pulse-access
        scanner
        sudo
        vboxusers
        video
      )
      for i in ${POWER_GROUPS[@]}; do
        $SUDO_CMD usermod -a -G "$i" "$SCRIPT_USER"
      done
    fi # group add confirmation
  fi # script_user is not root check

  if [[ ! -f /etc/sudoers.d/power_groups ]]; then
    unset CONFIRMATION
    read -p "Setup some additional sudoers stuff for groups [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD tee /etc/sudoers.d/power_groups > /dev/null <<'EOT'
%cdrom ALL=(root) NOPASSWD: /usr/bin/readom
%cdrom ALL=(root) NOPASSWD: /usr/bin/wodim
%disk ALL=(root) NOPASSWD: /bin/mount
%disk ALL=(root) NOPASSWD: /bin/umount
%netdev ALL=(root) NOPASSWD: /usr/sbin/openvpn
%cryptkeeper ALL=(root) NOPASSWD:/sbin/cryptsetup
EOT
      $SUDO_CMD chmod 440 /etc/sudoers.d/power_groups
    fi # confirmation on group stuff
  fi # ! -f /etc/sudoers.d/power_groups

  # set capabilities for network capture
  unset CONFIRMATION
  read -p "Set capabilities for netdev users to sniff [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    EXE_LESS_CAP=(
      /sbin/ethtool
      /usr/bin/bro
      /usr/bin/capstats
      /usr/bin/dumpcap
      /usr/bin/tcpflow
      /usr/bin/tcpreplay
      /usr/sbin/arpspoof
      /usr/sbin/dnsspoof
      /usr/sbin/dsniff
      /usr/sbin/filesnarf
      /usr/sbin/macof
      /usr/sbin/mailsnarf
      /usr/sbin/msgsnarf
      /usr/sbin/nethogs
      /usr/sbin/sshmitm
      /usr/sbin/sshow
      /usr/sbin/tcpdump
      /usr/sbin/tcpkill
      /usr/sbin/tcpnice
      /usr/sbin/urlsnarf
      /usr/sbin/webmitm
      /usr/sbin/webspy
    )
    EXE_MORE_CAP=(
      /usr/sbin/astraceroute
      /usr/sbin/bpfc
      /usr/sbin/curvetun
      /usr/sbin/flowtop
      /usr/sbin/ifpps
      /usr/sbin/mausezahn
      /usr/sbin/netsniff-ng
      /usr/sbin/trafgen
    )
    for i in ${EXE_LESS_CAP[@]}; do
      $SUDO_CMD chown root:netdev "$i" && \
        $SUDO_CMD setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' "$i"
    done
    for i in ${EXE_MORE_CAP[@]}; do
      $SUDO_CMD chown root:netdev "$i" && \
        $SUDO_CMD setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip CAP_IPC_LOCK+eip CAP_SYS_ADMIN+eip' "$i"
    done
  fi # setcap confirmation

  if dpkg -s ufw >/dev/null 2>&1; then
    unset CONFIRMATION
    read -p "Enable/configure UFW (uncomplicated firewall) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD ufw enable
      $SUDO_CMD ufw default deny incoming
      $SUDO_CMD ufw default allow outgoing
      UFW_ALLOW_RULES=(
        CIFS
        CUPS
        http
        https
        mosh
        nfs
        ntp
        ssh
        24800/tcp
        28400/tcp
        5044/tcp
        5601/tcp
        8443/tcp
        9200/tcp
        9443/tcp
      )
      for i in ${UFW_ALLOW_RULES[@]}; do
        $SUDO_CMD ufw allow "$i"
      done
    fi # ufw confirmation
  fi # ufw installed check

  if [[ -r /etc/sysctl.conf ]] && ! grep -q swappiness /etc/sysctl.conf; then
    unset CONFIRMATION
    read -p "Tweak sysctl.conf (swap, NIC buffers, handles, etc.) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD tee -a /etc/sysctl.conf > /dev/null <<'EOT'

# allow dmg reading
kernel.dmesg_restrict=0

# the maximum number of open file handles
fs.file-max=65536

# the maximum number of user inotify watches
fs.inotify.max_user_watches=131072

# the maximum number of memory map areas a process may have
vm.max_map_count=262144

# the maximum number of incoming connections
net.core.somaxconn=65535

# decrease "swappiness" (swapping out runtime memory vs. dropping pages)
vm.swappiness=1

# the % of system memory fillable with "dirty" pages before flushing
vm.dirty_background_ratio=40

# maximum % of dirty system memory before committing everything
vm.dirty_ratio=80

# network buffer sizes
net.core.netdev_max_backlog=250000
net.core.optmem_max=33554432
net.core.rmem_default=425984
net.core.rmem_max=33554432
net.core.somaxconn=65535
net.core.wmem_default=425984
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=10240 425984 33554432
net.ipv4.tcp_wmem=10240 425984 33554432
net.ipv4.udp_mem=10240 425984 33554432
EOT
    fi # sysctl confirmation
  fi # sysctl check

  if [[ ! -f /etc/security/limits.d/limits.conf ]]; then
    unset CONFIRMATION
    read -p "Increase limits for file handles and memlock [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD tee /etc/security/limits.d/limits.conf > /dev/null <<'EOT'
* soft nofile 65535
* hard nofile 65535
* soft memlock unlimited
* hard memlock unlimited
EOT
    fi # limits.conf confirmation
  fi # limits.conf check

  if [[ -f /etc/default/grub ]] && ! grep -q deadline /etc/default/grub; then
    unset CONFIRMATION
    read -p "Tweak kernel parameters in grub (scheduler, cgroup, etc.) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\).*/\1"elevator=deadline cgroup_enable=memory swapaccount=1 cgroup.memory=nokmem"/' /etc/default/grub
      $SUDO_CMD update-grub
    fi # grub confirmation
  fi # grub check

fi # linux

if [[ -n $GUERO_GITHUB_PATH ]] && [[ -d "$GUERO_GITHUB_PATH" ]]; then
  unset CONFIRMATION
  read -p "Setup symlinks for dotfiles in \"$GUERO_GITHUB_PATH\" [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then

    [[ -r "$GUERO_GITHUB_PATH"/bash/rc ]] && rm -vf ~/.bashrc && \
      ln -vrs "$GUERO_GITHUB_PATH"/bash/rc ~/.bashrc

    [[ -r "$GUERO_GITHUB_PATH"/bash/aliases ]] && rm -vf ~/.bash_aliases && \
      ln -vrs "$GUERO_GITHUB_PATH"/bash/aliases ~/.bash_aliases

    [[ -r "$GUERO_GITHUB_PATH"/bash/functions ]] && rm -vf ~/.bash_functions && \
      ln -vrs "$GUERO_GITHUB_PATH"/bash/functions ~/.bash_functions

    [[ -d "$GUERO_GITHUB_PATH"/bash/rc.d ]] && rm -vf ~/.bashrc.d && \
      ln -vrs "$GUERO_GITHUB_PATH"/bash/rc.d ~/.bashrc.d

    [[ -r "$GUERO_GITHUB_PATH"/git/gitconfig ]] && rm -vf ~/.gitconfig && \
      ln -vrs "$GUERO_GITHUB_PATH"/git/gitconfig ~/.gitconfig

    [[ -r "$GUERO_GITHUB_PATH"/git/gitignore_global ]] && rm -vf ~/.gitignore_global && \
      ln -vrs "$GUERO_GITHUB_PATH"/git/gitignore_global ~/.gitignore_global

    [[ $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/tmux/tmux.conf ]] && rm -vf ~/.tmux.conf && \
      ln -vrs "$GUERO_GITHUB_PATH"/linux/tmux/tmux.conf ~/.tmux.conf

    [[ $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/xxdiff/xxdiffrc ]] && rm -vf ~/.xxdiffrc && \
      ln -vrs "$GUERO_GITHUB_PATH"/linux/xxdiff/xxdiffrc ~/.xxdiffrc

    [[ -r "$GUERO_GITHUB_PATH"/gdb/gdbinit ]] && rm -vf ~/.gdbinit && \
      ln -vrs "$GUERO_GITHUB_PATH"/gdb/gdbinit ~/.gdbinit

    [[ -r "$GUERO_GITHUB_PATH"/gdb/cgdbrc ]] && mkdir -p ~/.cgdb && rm -vf ~/.cgdb/cgdbrc && \
      ln -vrs "$GUERO_GITHUB_PATH"/gdb/cgdbrc ~/.cgdb/cgdbrc

    [[ -r "$GUERO_GITHUB_PATH"/gdb/hexdump.py ]] && mkdir -p ~/.config/gdb && rm -vf ~/.config/gdb/hexdump.py && \
      ln -vrs "$GUERO_GITHUB_PATH"/gdb/hexdump.py ~/.config/gdb/hexdump.py

    [[ ! -d ~/.config/gdb/peda ]] && git clone --recursive https://github.com/longld/peda.git ~/.config/gdb/peda

    if [[ $LINUX ]] && [[ -d "$GUERO_GITHUB_PATH"/linux/lxde-desktop.config ]]; then
      while IFS= read -d $'\0' -r CONFDIR; do
        DIRNAME="$(basename "$CONFDIR")"
        rm -vf ~/.config/"$DIRNAME" && ln -vrs "$CONFDIR" ~/.config/"$DIRNAME"
      done < <(find "$GUERO_GITHUB_PATH"/linux/lxde-desktop.config -mindepth 1 -maxdepth 1 -type d -print0)
    fi

    [[ $LINUX ]] && dpkg -s albert >/dev/null 2>&1 && rm -vf ~/.config/autostart/albert.desktop && \
      ln -vrs /usr/share/applications/albert.desktop ~/.config/autostart/albert.desktop

    mkdir -p ~/.local/bin
    LINKED_SCRIPTS=(
      clarence-0.4.4
      keepassxc_delay.sh
      sound_cap.sh
      screenshot.sh
      tilix.sh
      vid_rename.sh
      vid_to_dvd_mpeg.sh
      windems.sh
    )
    for i in ${LINKED_SCRIPTS[@]}; do
      rm -vf ~/.local/bin/"$i" && ln -vrs "$GUERO_GITHUB_PATH"/scripts/"$i" ~/.local/bin/
    done

    [[ -r "$GUERO_GITHUB_PATH"/bash/context-color/context-color ]] && rm -vf ~/.local/bin/context-color && \
      ln -vrs "$GUERO_GITHUB_PATH"/bash/context-color/context-color ~/.local/bin/context-color

  fi # dotfiles setup confirmation
fi # dotfiles check for github checkout
