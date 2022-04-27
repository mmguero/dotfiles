#!/usr/bin/env bash

# This is my one-stop-shop Linux/*NIX box setup.
# If you are not me this may not be what you're looking for.

# add contents of https://raw.githubusercontent.com/mmguero/dotfiles/master/bash/rc.d/04_envs.bashrc
# to .bashrc after running this script (or let this script set up the symlinks for ~/.bashrc.d for you)

# Tested on:
# - Debian Linux
# - Debian on WSL (sort of)
# - macOS (sort of)
# - msys/mingw (sort of)

###################################################################################
# initialize

export DEBIAN_FRONTEND=noninteractive

if [[ -z "$BASH_VERSION" ]]; then
  echo "Wrong interpreter, please run \"$0\" with bash" >&2
  exit 1
fi

[[ "$(uname -s)" = 'Darwin' ]] && REALPATH=grealpath || REALPATH=realpath
[[ "$(uname -s)" = 'Darwin' ]] && DIRNAME=gdirname || DIRNAME=dirname
if ! (type "$REALPATH" && type "$DIRNAME") > /dev/null; then
  echo "$(basename "${BASH_SOURCE[0]}") requires $REALPATH and $DIRNAME" >&2
  exit 1
fi
SCRIPT_PATH="$($DIRNAME $($REALPATH -e "${BASH_SOURCE[0]}"))"
SCRIPT_NAME="$(basename $($REALPATH -e "${BASH_SOURCE[0]}"))"

LOCAL_DATA_PATH=${XDG_DATA_HOME:-$HOME/.local/share}
LOCAL_BIN_PATH=$HOME/.local/bin
LOCAL_CONFIG_PATH=${XDG_CONFIG_HOME:-$HOME/.config}

# see if this has been cloned from github.com/mmguero/dotfiles
# (so we can assume other stuff might be here for symlinking)
unset GUERO_GITHUB_PATH
if [[ $(basename "$SCRIPT_PATH") = 'bash' ]]; then
  pushd "$SCRIPT_PATH"/.. >/dev/null 2>&1
  if (( "$( (git remote -v 2>/dev/null | awk '{print $2}' | grep -P 'dotfiles(-private)?' | wc -l) || echo 0 )" > 0 )); then
    GUERO_GITHUB_PATH="$(pwd)"
  fi
  popd >/dev/null 2>&1
fi

###################################################################################
# variables for env development environments and tools

ENV_LIST=(
  python
  ruby
  golang
  nodejs
  yarn
  perl
  rust
  age
  bat
  fd
  jq
  yq
  ripgrep
  tmux
)

DOCKER_COMPOSE_INSTALL_VERSION=( 1.29.2 )

###################################################################################
# determine OS
unset MACOS
unset LINUX
unset WSL
unset MSYS
unset HAS_SCOOP
unset LINUX_DISTRO
unset LINUX_RELEASE
unset LINUX_ARCH
unset LINUX_CPU

if [[ $(uname -s) = 'Darwin' ]]; then
  export MACOS=0

elif [[ -n $MSYSTEM ]]; then
  export MSYS=0
  command -v scoop >/dev/null 2>&1 && export HAS_SCOOP=0
  command -v cygpath >/dev/null 2>&1 && \
    [[ -n $HAS_SCOOP ]] && \
    [[ -n $USERPROFILE ]] && \
    [[ -d "$(cygpath -u "$USERPROFILE")"/scoop/shims ]] && \
    export PATH="$(cygpath.exe -u $USERPROFILE)"/scoop/shims:"$PATH"

else
  if grep -q Microsoft /proc/version; then
    export WSL=0
  fi
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
if [[ -n $MACOS ]]; then
  SCRIPT_USER="$(whoami)"
  SUDO_CMD=""

elif [[ -n $MSYS ]]; then
  SCRIPT_USER="$(whoami)"
  SUDO_CMD=""

else
  if [[ $EUID -eq 0 ]]; then
    SCRIPT_USER="root"
    SUDO_CMD=""
  else
    SCRIPT_USER="$(whoami)"
    SUDO_CMD="sudo"
  fi
  if ! dpkg -s apt >/dev/null 2>&1; then
    echo "This command only target Linux distributions that use apt/apt-get" >&2
    exit 1
  fi
  LINUX_ARCH="$(dpkg --print-architecture)"
  LINUX_CPU="$(uname -m)"
fi


###################################################################################
# convenience function for installing curl/git/jq/moreutils for cloning/downloading
function InstallEssentialPackages {
  if command -v curl >/dev/null 2>&1 && \
     command -v git >/dev/null 2>&1 && \
     command -v jq >/dev/null 2>&1 && \
     command -v sponge >/dev/null 2>&1; then
    echo "\"curl\", \"git\", \"jq\" and \"moreutils\" are already installed!" >&2
  else
    echo "Installing curl, git, jq and moreutils..." >&2
    if [[ -n $MACOS ]]; then
      brew install git jq moreutils # since Jaguar curl is already installed in MacOS
    elif [[ -n $MSYS ]]; then
      [[ -n $HAS_SCOOP ]] && scoop install main/curl main/git main/jq || pacman -Sy curl git ${MINGW_PACKAGE_PREFIX}-jq
      pacman --noconfirm -Sy moreutils
    elif [[ -n $LINUX ]]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1 && \
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y curl git jq moreutils
    fi
  fi
}

###################################################################################
function _GitClone {
  git clone --depth=1 --single-branch --recurse-submodules --shallow-submodules --no-tags "$@"
}

###################################################################################
function _GitLatestRelease {
  if [[ -n "$1" ]]; then
    (set -o pipefail && curl -sL -f "https://api.github.com/repos/$1/releases/latest" | jq '.tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
      (set -o pipefail && curl -sL -f "https://api.github.com/repos/$1/releases" | jq '.[0].tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
      echo unknown
  else
    echo "unknown">&2
  fi
}

###################################################################################
# function to set up paths and init things after env installations
function _EnvSetup {
  if [[ -z $MSYS ]]; then

    if [[ -d "${ASDF_DIR:-$HOME/.asdf}" ]]; then
      . "${ASDF_DIR:-$HOME/.asdf}"/asdf.sh
      if [[ -n $ASDF_DIR ]]; then
        . "${ASDF_DIR:-$HOME/.asdf}"/completions/asdf.bash
        for i in ${ENV_LIST[@]}; do
          asdf reshim "$i" >/dev/null 2>&1 || true
        done
      fi
    fi

    export PYTHONDONTWRITEBYTECODE=1

    if [[ -n $ASDF_DIR ]]; then
      if asdf plugin list | grep -q golang; then
        [[ -z $GOROOT ]] && go version >/dev/null 2>&1 && export GOROOT="$(go env GOROOT)"
        [[ -z $GOPATH ]] && go version >/dev/null 2>&1 && export GOPATH="$(go env GOPATH)"
      fi
      if (asdf plugin list | grep -q rust) && (asdf current rust >/dev/null 2>&1); then
        . "$ASDF_DIR"/installs/rust/"$(asdf current rust | awk '{print $2}')"/env
      fi
    fi
  fi
}

################################################################################
# brew on macOS
function SetupMacOSBrew {
  if [[ -n $MACOS ]]; then

    # install brew, if needed
    if ! command -v brew >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "\"brew\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        echo "Installing brew..." >&2
        # kind of a chicken-egg situation here with curl/brew, but I think macOS has it installed already
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
      fi
    else
      echo "\"brew\" is already installed!" >&2
    fi # brew install check

    brew list --cask >/dev/null 2>&1
    brew tap homebrew/cask-versions
    brew tap homebrew/cask-fonts

  fi # MacOS check
}

################################################################################
# scoop on on windows 10
function SetupWindowsScoop {
  if [[ -n $MSYS ]]; then

    # TODO
    echo "todo" >&2
  fi # MSYS check
}

################################################################################
# envs (via asdf)
function InstallEnvs {
  if [[ -z $MSYS ]]; then
    declare -A ENVS_INSTALLED
    for i in ${ENV_LIST[@]}; do
      ENVS_INSTALLED[$i]=false
    done

    if ([[ -n $ASDF_DIR ]] && [[ ! -d "$ASDF_DIR" ]]) || ([[ -z $ASDF_DIR ]] && [[ ! -d "$HOME"/.asdf ]]) ; then
      ASDF_DIR="${ASDF_DIR:-$HOME/.asdf}"
      unset CONFIRMATION
      read -p "\"asdf\" is not installed, attempt to install it [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        git clone --recurse-submodules --shallow-submodules https://github.com/asdf-vm/asdf.git "$ASDF_DIR"
        pushd "$ASDF_DIR" >/dev/null 2>&1
        git checkout "$(git describe --abbrev=0 --tags)"
        popd >/dev/null 2>&1
      fi
    fi

    if [[ -d "${ASDF_DIR:-$HOME/.asdf}" ]]; then
      _EnvSetup
      if [[ -n $ASDF_DIR ]]; then
        asdf update
        for i in ${ENV_LIST[@]}; do
          if ! ( asdf plugin list | grep -q "$i" ) >/dev/null 2>&1 ; then
            unset CONFIRMATION
            read -p "\"$i\" is not installed, attempt to install it [y/N]? " CONFIRMATION
            CONFIRMATION=${CONFIRMATION:-N}
            if [[ $CONFIRMATION =~ ^[Yy] ]]; then
              asdf plugin add "$i" && ENVS_INSTALLED[$i]=true
            fi
          else
            unset CONFIRMATION
            read -p "\"$i\" is already installed, attempt to update it [y/N]? " CONFIRMATION
            CONFIRMATION=${CONFIRMATION:-N}
            if [[ $CONFIRMATION =~ ^[Yy] ]]; then
              ENVS_INSTALLED[$i]=true
            fi
          fi
        done
      fi
      _EnvSetup
    fi # .asdf check

    # install versions of the tools and plugins

    # python (build deps)
    if [[ ${ENVS_INSTALLED[python]} = 'true' ]]; then
      if [[ -n $LINUX ]]; then
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
          wget \
          xz-utils \
          zlib1g-dev
      fi
    fi

    # tmux (build deps)
    if [[ ${ENVS_INSTALLED[tmux]} = 'true' ]]; then
      if [[ -n $LINUX ]]; then
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
          automake \
          autotools-dev \
          bison \
          build-essential \
          make \
          unzip
      fi
    fi

    for i in ${ENV_LIST[@]}; do
      if [[ ${ENVS_INSTALLED[$i]} = 'true' ]]; then
        asdf plugin update $i
        asdf install $i latest
        asdf global $i latest
        asdf reshim $i
      fi
    done
    _EnvSetup
  fi
}

################################################################################
# InstallEnvPackages
function InstallEnvPackages {
  unset CONFIRMATION
  read -p "Install common pip/go/etc. packages [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    _EnvSetup

    if python3 -m pip -V >/dev/null 2>&1; then
      python3 -m pip install -U \
        beautifulsoup4 \
        black \
        chepy[extras] \
        colorama \
        colored \
        cryptography \
        Cython \
        dateparser \
        entrypoint2 \
        git+https://github.com/badele/gitcheck.git \
        git-up \
        humanhash3 \
        jinja2 \
        magic-wormhole \
        mmguero \
        nikola \
        patool \
        Pillow \
        psutil \
        py-cui \
        pyshark \
        python-dateutil \
        python-magic \
        pythondialog \
        pyunpack \
        requests\[security\] \
        ruamel.yaml \
        scapy \
        urllib3

      [[ ! -d "$LOCAL_CONFIG_PATH"/chepy_plugins ]] && _GitClone https://github.com/securisec/chepy_plugins "$LOCAL_CONFIG_PATH"/chepy_plugins
    fi

    if command -v go >/dev/null 2>&1; then
      go get -u -v github.com/rogpeppe/godef
      go get -u -v golang.org/x/tools/cmd/goimports
      go get -u -v golang.org/x/tools/cmd/gorename
      go get -u -v golang.org/x/term
      go get -u -v github.com/nsf/gocode
      popd >/dev/null 2>&1
    fi
  fi

  _EnvSetup
}

################################################################################
# setup debian apt sources
function SetupAptSources {
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
        # some manual ones
        GPG_KEY_URLS=(
        )
        for i in ${GPG_KEY_URLS[@]}; do
          curl -fsSL "$i" | $SUDO_CMD apt-key add -
        done
      fi
    fi

  fi
}

################################################################################
function InstallDocker {
  if [[ -n $MACOS ]]; then

    # install docker-edge, if needed
    if ! brew list --cask --versions docker-edge >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "\"docker-edge\" cask is not installed, attempt to install docker-edge via brew [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        echo "Installing Docker Edge..." >&2
        brew install --cask docker-edge
        echo "Installed Docker Edge." >&2
        echo "Please modify performance settings as needed" >&2
      fi # docker install confirmation check
    else
      echo "\"docker-edge\" is already installed!" >&2
    fi # docker-edge install check

  elif [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    # install docker-ce, if needed
    if ! $SUDO_CMD docker info >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "\"docker info\" failed, attempt to install docker [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then

        InstallEssentialPackages

        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
                                                   apt-transport-https \
                                                   ca-certificates \
                                                   curl \
                                                   gnupg2 \
                                                   software-properties-common

        curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO_CMD apt-key add -

        echo "Installing Docker CE..." >&2
        if [[ "$LINUX_DISTRO" == "Ubuntu" ]]; then
          $SUDO_CMD add-apt-repository \
             "deb [arch=$LINUX_ARCH] https://download.docker.com/linux/ubuntu \
             $LINUX_RELEASE \
             stable"
        elif [[ "$LINUX_DISTRO" == "Raspbian" ]]; then
          $SUDO_CMD add-apt-repository \
             "deb [arch=$LINUX_ARCH] https://download.docker.com/linux/raspbian \
             $LINUX_RELEASE \
             stable"
        elif [[ "$LINUX_DISTRO" == "Debian" ]]; then
          $SUDO_CMD add-apt-repository \
             "deb [arch=$LINUX_ARCH] https://download.docker.com/linux/debian \
             $LINUX_RELEASE \
             stable"
        fi

        $SUDO_CMD apt-get update -qq >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y docker-ce

        if [[ "$SCRIPT_USER" != "root" ]]; then
          echo "Adding \"$SCRIPT_USER\" to group \"docker\"..." >&2
          $SUDO_CMD usermod -a -G docker "$SCRIPT_USER"
          echo "You will need to log out and log back in for this to take effect" >&2
        fi

      fi # docker install confirmation check

    else
      echo "\"docker\" is already installed!" >&2
    fi # docker install check

    if [[ -f /etc/docker/daemon.json ]] && ! grep -q buildkit /etc/docker/daemon.json; then
      unset CONFIRMATION
      read -p "Enable Docker buildkit [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        (cat /etc/docker/daemon.json 2>/dev/null || echo '{}') | jq '. + { "features": { "buildkit": true } }' | $SUDO_CMD sponge /etc/docker/daemon.json
        ( $SUDO_CMD systemctl daemon-reload && $SUDO_CMD systemctl restart docker ) || true
      fi
    fi

    # install docker-compose, if needed
    if ! docker-compose version >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "\"docker-compose version\" failed, attempt to install docker-compose [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        if python3 -m pip -V >/dev/null 2>&1 ; then
          echo "Installing Docker Compose via pip..." >&2
          python3 -m pip install -U docker-compose
          if ! docker-compose version >/dev/null 2>&1 ; then
            echo "Installing docker-compose failed" >&2
            exit 1
          fi
        else
          echo "Installing Docker Compose via curl to /usr/local/bin..." >&2
          InstallEssentialPackages
          $SUDO_CMD curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_INSTALL_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
          $SUDO_CMD chmod +x /usr/local/bin/docker-compose
          if ! /usr/local/bin/docker-compose version >/dev/null 2>&1 ; then
            echo "Installing docker-compose failed" >&2
            exit 1
          fi
        fi # pip3 vs. curl for docker-compose install
      fi # docker-compose install confirmation check
    else
      echo "\"docker-compose\" is already installed!" >&2
    fi # docker-compose install check

    unset CONFIRMATION
    read -p "Install distrobox [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- -p "$LOCAL_BIN_PATH"
    fi

    unset CONFIRMATION
    read -p "Configure user namespaces [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y uidmap fuse-overlayfs

      $SUDO_CMD tee -a /etc/sysctl.conf > /dev/null <<'EOT'

# allow unprivileged user namespaces
kernel.unprivileged_userns_clone=1
EOT
      echo "options overlay permit_mounts_in_userns=1" | $SUDO_CMD tee /etc/modprobe.d/10-docker.conf
    fi

  fi # MacOS vs. Linux for docker
}

################################################################################
function DockerPullImages {
  if $SUDO_CMD docker info >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "Pull common docker images (Linux distributions) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        alpine:latest
        amazonlinux:2
        debian:stable-slim
        ubuntu:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull images confirmation

    unset CONFIRMATION
    read -p "Pull common docker images (media) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        erichough/kodi:latest
        ghcr.io/mmguero/cleanvid:latest
        ghcr.io/mmguero/lossless-cut:latest
        ghcr.io/mmguero/montag:latest
        jess/spotify:latest
        mwader/static-ffmpeg:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull media images confirmation

    unset CONFIRMATION
    read -p "Pull common docker images (web services) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/nginx-ldap:latest
        ghcr.io/mmguero/stunnel:latest
        ghcr.io/mmguero/tunneler:latest
        ghcr.io/mmguero/wireproxy:latest
        haugene/transmission-openvpn:latest
        nginx:latest
        traefik/whoami:latest
        traefik:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull web images confirmation

    unset CONFIRMATION
    read -p "Pull common docker images (web browsers) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        andrewmackrodt/chromium-x11:latest
        ghcr.io/mmguero/firefox:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull web images confirmation

    unset CONFIRMATION
    read -p "Pull common docker images (office) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        woahbase/alpine-libreoffice:latest
        woahbase/alpine-gimp:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull office confirmation

    unset CONFIRMATION
    read -p "Pull common docker images (desktop environment) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/xfce-base:latest
        ghcr.io/mmguero/xfce-ext:latest
        ghcr.io/mmguero/xfce:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull desktop environment

    unset CONFIRMATION
    read -p "Pull common docker images (deblive) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/deblive:latest
        tianon/qemu:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull desktop environment

    unset CONFIRMATION
    read -p "Pull common docker images (communication) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/mattermost-server:latest
        ghcr.io/mmguero/mirotalk:latest
        ghcr.io/mmguero/postgres:latest
        ghcr.io/mmguero/signal:latest
        ghcr.io/mmguero/teams:latest
        mdouchement/zoom-us:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull communication images confirmation

    unset CONFIRMATION
    read -p "Pull common docker images (forensics) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/capa:latest
        ghcr.io/mmguero/zeek:latest
        ghcr.io/idaholab/navv:latest
        mpepping/cyberchef:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull forensics images confirmation

    unset CONFIRMATION
    read -p "Pull common docker images (docker) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        hello-world:latest
        nate/dockviz:latest
        wagoodman/dive:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        docker pull "$i"
      done
    fi # docker pull docker images confirmation

  fi # docker is there
}

################################################################################
# VirtualBox and vagrant
function InstallVirtualization {
  if [[ -n $MACOS ]]; then

    VIRT_CASK_NAMES=(
      vmware-fusion
      virtualbox
      vagrant
      vagrant-manager
    )
    for i in ${VIRT_CASK_NAMES[@]}; do
      if ! brew list --cask --versions "$i" >/dev/null 2>&1 ; then
        unset CONFIRMATION
        read -p "$i cask is not installed, attempt to install $i via brew [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          echo "Installing $i..." >&2
          brew install --cask "$i"
          echo "Installed $i." >&2
        fi # install confirmation check
      else
        echo "$i is already installed!" >&2
      fi # already installed check
    done

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then

    unset CONFIRMATION
    read -p "Install VirtualBox [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add nonportable
      scoop install main/sudo
      sudo scoop install nonportable/virtualbox-np
    fi

    unset CONFIRMATION
    read -p "Install Vagrant [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && scoop install main/vagrant

    unset CONFIRMATION
    read -p "Install Packer [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && scoop install main/packer

  elif [[ -n $LINUX ]] && [[ -z $WSL ]] && [[ "$LINUX_CPU" == "x86_64" ]]; then

    # virtualbox or kvm
    $SUDO_CMD apt-get update -qq >/dev/null 2>&1

    unset CONFIRMATION
    read -p "Install kvm/libvirt/qemu [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system virtinst
      unset CONFIRMATION
      read -p "Install kvm/libvirt/qemu GUI packages [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y --no-install-recommends virt-manager gir1.2-spiceclientgtk-3.0
      fi
      if [[ "$SCRIPT_USER" != "root" ]]; then
        echo "Adding \"$SCRIPT_USER\" to group \"libvirt\"..." >&2
        $SUDO_CMD usermod -a -G libvirt "$SCRIPT_USER"
        echo "You will need to log out and log back in for this to take effect" >&2
      fi
    fi # Check kvm/libvirt/qemu installation?

    unset CONFIRMATION
    read -p "Install VirtualBox [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      if ! command -v VBoxManage >/dev/null 2>&1 ; then
        unset VBOX_PACKAGE_NAME
        VBOX_PACKAGE_NAMES=(
          virtualbox
          virtualbox-6.1
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
              echo "Adding \"$SCRIPT_USER\" to group \"vboxusers\"..." >&2
              $SUDO_CMD usermod -a -G vboxusers "$SCRIPT_USER"
              echo "You will need to log out and log back in for this to take effect" >&2
            fi
          fi

          if [[ "$VBOX_PACKAGE_NAME" == "virtualbox" ]]; then
            # virtualbox guest additions ISO
            VBOX_ISO_PACKAGE_CANDIDATE="$(apt-cache policy virtualbox-guest-additions-iso | grep Candidate: | awk '{print $2}' | grep -v '(none)')"
            if [[ -n $VBOX_ISO_PACKAGE_CANDIDATE ]]; then
              unset CONFIRMATION
              read -p "Install virtualbox-guest-additions-iso [Y/n]? " CONFIRMATION
              CONFIRMATION=${CONFIRMATION:-Y}
              if [[ $CONFIRMATION =~ ^[Yy] ]]; then
                DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y virtualbox-guest-additions-iso
              fi
            fi

            # virtualbox extension pack
            VBOX_EXT_PACKAGE_CANDIDATE="$(apt-cache policy virtualbox-ext-pack | grep Candidate: | awk '{print $2}' | grep -v '(none)')"
            if [[ -n $VBOX_EXT_PACKAGE_CANDIDATE ]]; then
              unset CONFIRMATION
              read -p "Install virtualbox-ext-pack [Y/n]? " CONFIRMATION
              CONFIRMATION=${CONFIRMATION:-Y}
              if [[ $CONFIRMATION =~ ^[Yy] ]]; then
                DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y virtualbox-ext-pack
              fi
            fi

          else
            VBOX_EXTPACK_URL="$(curl -fsL "https://www.virtualbox.org/wiki/Downloads" | grep -oP "https://.*?vbox-extpack" | sort -V | head -n 1)"
            unset CONFIRMATION
            read -p "Download and install $VBOX_EXTPACK_URL [Y/n]? " CONFIRMATION
            CONFIRMATION=${CONFIRMATION:-Y}
            if [[ $CONFIRMATION =~ ^[Yy] ]]; then
              VBOX_EXTPACK_FNAME="$(echo "$VBOX_EXTPACK_URL" | sed "s@.*/@@")" >&2
              pushd /tmp >/dev/null 2>&1
              curl -L -J -O "$VBOX_EXTPACK_URL"
              if [[ -r "$VBOX_EXTPACK_FNAME" ]]; then
                $SUDO_CMD VBoxManage extpack install --accept-license=56be48f923303c8cababb0bb4c478284b688ed23f16d775d729b89a2e8e5f9eb --replace "$VBOX_EXTPACK_FNAME"
              else
                echo "Error downloading $VBOX_EXTPACK_URL to $VBOX_EXTPACK_FNAME" >&2
              fi
              popd >/dev/null 2>&1
            fi
          fi
        fi

      else
        echo "\"virtualbox\" is already installed!" >&2
      fi # check VBoxManage is not in path to see if some form of virtualbox is already installed
    fi # Check VirtualBox installation?

    # install Vagrant
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
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y vagrant

      elif $SUDO_CMD docker info >/dev/null 2>&1 ; then
        unset CONFIRMATION
        read -p "Pull ghcr.io/mmguero/vagrant-libvirt:latest instead [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          docker pull ghcr.io/mmguero/vagrant-libvirt:latest
        fi
      fi
    fi

    unset CONFIRMATION
    read -p "Attempt to download and install latest version of Packer from releases.hashicorp.com [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      curl -sSL -o /tmp/packer.zip "$(curl -sSL https://www.packer.io/downloads|grep -oP '"url":"https://releases\.hashicorp\.com/packer/.*?_linux_amd64\.zip"' | grep -v '{' | sort --version-sort | tail -n 1 | cut -d: -f2- | tr -d '"')"
      pushd /tmp >/dev/null 2>&1
      gunzip -f -S .zip packer.zip
      chmod 755 ./packer
      mkdir -p "$LOCAL_BIN_PATH"
      mv ./packer "$LOCAL_BIN_PATH"
      popd >/dev/null 2>&1
    fi

  fi # MacOS vs. Linux for virtualbox/kvm/vagrant

  # see if we want to install vagrant plugins
  if command -v vagrant >/dev/null 2>&1; then
    unset CONFIRMATION
    read -p "Install/update common vagrant plugins [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      VAGRANT_PLUGINS=(
        vagrant-mutate
        vagrant-reload
        vagrant-scp
        vagrant-sshfs
      )
      for i in ${VAGRANT_PLUGINS[@]}; do
        if (( "$( vagrant plugin list | grep -c "^$i " )" == 0 )); then
          vagrant plugin install $i
        fi
      done
      vagrant plugin update all
    fi # vagrant plugin install confirmation

    unset CONFIRMATION
    read -p "Install common vagrant boxes (linux) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      VAGRANT_BOXES=(
        bento/almalinux-8
        bento/debian-11
        bento/ubuntu-21.10
        clink15/pxe
        gbailey/amzn2
      )
      for i in ${VAGRANT_BOXES[@]}; do
        if (( "$( vagrant box list | grep -c "^$i " )" == 0 )); then
          vagrant box add $i
        fi
      done
      vagrant box outdated --global | grep "is outdated" | grep -vi "win" | awk '{print $2}' | xargs -r -l vagrant box update --box
      vagrant box prune -f -k
    fi # linux vagrant boxes install confirmation

    unset CONFIRMATION
    read -p "Install common vagrant boxes (windows) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      VAGRANT_BOXES=(
        StefanScherer/windows_10
        peru/windows-10-enterprise-x64-eval
      )
      for i in ${VAGRANT_BOXES[@]}; do
        if (( "$( vagrant box list | grep -c "^$i " )" == 0 )); then
          vagrant box add $i
        fi
      done
      vagrant box outdated --global | grep "is outdated" | grep -i "win" | awk '{print $2}' | xargs -r -l vagrant box update --box
      vagrant box prune -f -k
    fi # windows vagrant boxes install confirmation

  fi # check for vagrant being installed

}

################################################################################
function InstallCommonPackages {
  if [[ -n $MACOS ]]; then

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
      brew install gpg

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
      brew install jq
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

      brew install neilotoole/sq/sq
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then

    unset CONFIRMATION
    read -p "Install common packages [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add extras
      scoop install main/dark
      scoop install main/innounp
      scoop install main/7zip
      scoop install main/bat
      scoop install main/cloc
      scoop install main/diffutils
      scoop install main/dos2unix
      scoop install main/fd
      scoop install main/file
      scoop install main/findutils
      scoop install main/gnupg
      scoop install main/gron
      scoop install main/jdupes
      scoop install main/patch
      scoop install main/python
      scoop install main/ripgrep
      scoop install main/sudo
      scoop install main/time
      scoop install main/unrar
      scoop install main/unzip
      scoop install main/vim
      scoop install main/yq
      scoop install main/zip
      scoop install extras/age
    fi

  elif [[ -n $LINUX ]]; then
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
        bc
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
        dirmngr
        eject
        exfat-fuse
        exfat-utils
        fdisk
        fdupes
        file
        findutils
        firmware-amd-graphics
        firmware-iwlwifi
        firmware-linux
        firmware-linux-free
        firmware-linux-nonfree
        firmware-misc-nonfree
        flex
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
        htop
        jq
        less
        libcap2-bin
        libsecret-1-0
        libsecret-1-dev
        libsecret-tools
        libsquashfuse0
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
        squashfs-tools
        squashfuse
        strace
        sysstat
        time
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
        if [[ ! $i =~ ^firmware ]] || [[ -z $WSL ]]; then
          DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
        fi
      done

      # post-install configurations
      $SUDO_CMD make --directory=/usr/share/doc/git/contrib/credential/libsecret

      $SUDO_CMD groupadd fuse
      $SUDO_CMD groupadd cryptkeeper

      if dpkg -s localepurge >/dev/null 2>&1 ; then
        $SUDO_CMD dpkg-reconfigure --frontend=noninteractive localepurge
        $SUDO_CMD localepurge
        rm -f /tmp/localepurge-preseed.cfg
      fi

      $SUDO_CMD dpkg-reconfigure --frontend=noninteractive wireshark-common

      # veracrypt
      curl -L -o "/tmp/veracrypt-console-Debian-10.deb" "$(curl -sSL https://www.veracrypt.fr/en/Downloads.html | grep -Pio "https://.+?veracrypt-console.+?Debian-10-${LINUX_ARCH}.deb" | sed "s/&#43;/+/" | head -n 1)"
      $SUDO_CMD dpkg -i "/tmp/veracrypt-console-Debian-10.deb"
      rm -f "/tmp/veracrypt-console-Debian-10.deb"

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
  fi # Mac vs not-mac
}

################################################################################
function InstallCommonPackagesGUI {
  if [[ -n $MACOS ]]; then

    unset CONFIRMATION
    read -p "Install common casks [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      brew install --cask diskwave
      brew install --cask firefox
      brew install --cask homebrew/cask-fonts/font-hack
      brew install --cask iterm2
      brew install --cask keepassxc
      brew install --cask libreoffice
      brew install --cask ngrok
      brew install --cask osxfuse
      brew install --cask sublime-text
      brew install --cask veracrypt
      brew install --cask wireshark
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then

    unset CONFIRMATION
    read -p "Install common packages (GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add extras
      scoop install main/msys2
      scoop install extras/bulk-crap-uninstaller
      scoop install extras/conemu
      echo "conemu task for $MSYSTEM:" >&2
      echo "set \"PATH=%homedrive%%homepath%\scoop\apps\msys2\current\usr\bin;%PATH%\" & set CHERE_INVOKING=1 & set MSYSTEM=$MSYSTEM & set MSYS2_PATH_TYPE=inherit & set LC_ALL=C.UTF-8 & set LANG=C.UTF-8 & \"%homedrive%%homepath%\scoop\apps\conemu\current\ConEmu\conemu-msys2-64.exe\" \"%homedrive%%homepath%\scoop\apps\msys2\current\usr\bin\bash.exe\" --login -i -new_console:p" >&2
      scoop install extras/cpu-z
      scoop install extras/libreoffice
      scoop install extras/meld
      scoop install extras/sublime-text
      scoop install extras/sumatrapdf
      scoop install extras/sysinternals
      scoop install extras/win32-disk-imager
    fi

  elif [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    unset CONFIRMATION
    read -p "Install common packages (GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      DEBIAN_PACKAGE_LIST=(
        arandr
        dconf-cli
        fonts-noto-color-emoji
        fonts-hack-ttf
        ghex
        gparted
        gtk2-engines-murrine
        gtk2-engines-pixbuf
        keepassxc
        meld
        numix-gtk-theme
        obsidian-icon-theme
        pdftk
        regexxer
        rofi
        seahorse
        sublime-text
        thunar
        thunar-archive-plugin
        thunar-volman
        tilix
        ttf-mscorefonts-installer
        xautomation
        xbindkeys
        xdiskusage
        xfdesktop4
        xxdiff
        xxdiff-scripts
        xsel
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done

      if [[ ! -d "$HOME"/.themes/vimix-dark-laptop-beryl ]]; then
        TMP_CLONE_DIR="$(mktemp -d)"
        _GitClone https://github.com/vinceliuice/vimix-gtk-themes "$TMP_CLONE_DIR"
        pushd "$TMP_CLONE_DIR" >/dev/null 2>&1
        mkdir -p "$HOME"/.themes
        ./install.sh -d "$HOME"/.themes -n vimix -c dark -t beryl -s laptop
        popd >/dev/null 2>&1
        rm -rf "$TMP_CLONE_DIR"
      fi
    fi

  fi # Mac vs Linux
}

################################################################################
function InstallCommonPackagesMedia {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    unset CONFIRMATION
    read -p "Install common packages (media) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      DEBIAN_PACKAGE_LIST=(
        audacious
        audacity
        ffmpeg
        kazam
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
      if python3 -m pip -V >/dev/null 2>&1 ; then
        python3 -m pip install -U yt-dlp cleanvid monkeyplug montag-cleaner
      fi

      unset CONFIRMATION
      read -p "Install common packages (media/GIMP) [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        $SUDO_CMD apt-get update -qq >/dev/null 2>&1
        DEBIAN_PACKAGE_LIST=(
          gimp
          gimp-gmic
          gimp-plugin-registry
          gimp-texturize
        )
        for i in ${DEBIAN_PACKAGE_LIST[@]}; do
          DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
        done
      fi

    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then

    unset CONFIRMATION
    read -p "Install common packages (media) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      scoop bucket add extras
      scoop install main/ffmpeg
      scoop install main/imagemagick
      scoop install extras/audacious
      scoop install extras/audacity
      scoop install extras/irfanview
      scoop install extras/mkvtoolnix
      scoop install extras/mpv
      scoop install extras/vlc

      unset CONFIRMATION
      read -p "Install common packages (media/GIMP) [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      [[ $CONFIRMATION =~ ^[Yy] ]] && scoop install extras/gimp

      unset CONFIRMATION
      read -p "Install common packages (media/reaper) [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      [[ $CONFIRMATION =~ ^[Yy] ]] && scoop install extras/reaper

      unset CONFIRMATION
      read -p "Install common packages (media/losslesscut) [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      [[ $CONFIRMATION =~ ^[Yy] ]] && scoop install extras/losslesscut
    fi
  fi # Linux vs. MSYS
}

################################################################################
function InstallCommonPackagesNetworking {
  if [[ -n $LINUX ]]; then

    unset CONFIRMATION
    read -p "Install common packages (networking) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      DEBIAN_PACKAGE_LIST=(
        apache2-utils
        autossh
        bridge-utils
        cifs-utils
        cryptcat
        curl
        dnsutils
        dsniff
        ethtool
        iproute2
        mosh
        ncat
        net-tools
        netsniff-ng
        ngrep
        nmap
        openbsd-inetd
        openresolv
        openssh-client
        openvpn
        rsync
        socat
        sshfs
        ssldump
        stunnel4
        tcpdump
        telnet
        traceroute
        tshark
        wget
        whois
        wireguard
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Install common packages (networking) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add extras
      scoop bucket add smallstep https://github.com/smallstep/scoop-bucket.git
      scoop install main/autossh
      scoop install main/boringproxy
      scoop install main/croc
      scoop install main/cwrsync
      scoop install main/ffsend
      scoop install main/netcat
      scoop install main/nmap
      scoop install main/ngrok
      scoop install main/termshark
      scoop install main/wget
      scoop install extras/stunnel
      scoop install smallstep/step
      echo '$ step ca bootstrap --ca-url https://step.example.org:9000 --fingerprint xxxxxxx --install' >&2
      echo '$ cp ~/.step/certs/root_ca.crt /etc/pki/ca-trust/source/anchors/example.crt' >&2
      echo '$ update-ca-trust' >&2
      echo 'for firefox: set security.enterprise_roots.enabled to true' >&2
    fi

  fi # Linux vs. MSYS
}

################################################################################
function InstallLatestFirefoxLinuxAmd64 {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then
    if [[ "$LINUX_ARCH" == "amd64" ]]; then
      curl -o /tmp/firefox.tar.bz2 -L "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US"
      if [[ $(file -b --mime-type /tmp/firefox.tar.bz2) = 'application/x-bzip2' ]]; then
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
  fi # Linux
}


################################################################################
function InstallCommonPackagesNetworkingGUI {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    unset CONFIRMATION
    read -p "Install common packages (networking, GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      DEBIAN_PACKAGE_LIST=(
        wireshark
        x2goclient
        zenmap
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done

      if [[ "$LINUX_ARCH" == "amd64" ]]; then
        curl -sSL -o /tmp/synergy_debian_amd64.deb "https://filedn.com/lqGgqyaOApSjKzN216iPGQf/Software/Linux/synergy_debian_amd64.deb"
        $SUDO_CMD dpkg -i /tmp/synergy_debian_amd64.deb
        rm -f /tmp/synergy_debian_amd64.deb
      fi
    fi

    if [[ "$LINUX_ARCH" == "amd64" ]]; then
      unset CONFIRMATION
      read -p "Install latest Firefox [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        InstallLatestFirefoxLinuxAmd64
      fi
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Install common packages (networking, GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add extras
      scoop install extras/putty
      scoop install extras/winscp
      scoop install extras/filezilla

      unset CONFIRMATION
      read -p "Install Firefox [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      [[ $CONFIRMATION =~ ^[Yy] ]] && scoop install extras/firefox

      unset CONFIRMATION
      read -p "Install Chromium [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      [[ $CONFIRMATION =~ ^[Yy] ]] && scoop install extras/chromium

      unset CONFIRMATION
      read -p "Install common packages (networking, VPN) [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        scoop bucket add nonportable
        scoop install main/sudo
        scoop install extras/wireshark
        sudo scoop install extras/openvpn
        sudo scoop install nonportable/wireguard-np
      fi
    fi

  fi # Linux vs. MSYS
}

################################################################################
function InstallCommonPackagesForensics {
  if [[ -n $LINUX ]]; then

    unset CONFIRMATION
    read -p "Install common packages (forensics/security) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      DEBIAN_PACKAGE_LIST=(
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
        ewf-tools
        exif
        exiftags
        ext3grep
        fbi
        foremost
        gddrescue
        gpart
        hunt
        hydra
        john
        john-data
        knocker
        libafflib0v5
        libewf2
        libguytools2
        nast
        nasty
        nikto
        p0f
        plaso
        safecat
        scsitools
        testdisk
        weplab
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Install common packages (forensics/security) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop install main/adb
      scoop install main/exiftool
      scoop install extras/testdisk
    fi

  fi # Linux vs. MSYS
}


################################################################################
function InstallCommonPackagesForensicsGUI {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then
    unset CONFIRMATION
    read -p "Install common packages (forensics/security, GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      $SUDO_CMD apt-get update -qq >/dev/null 2>&1
      DEBIAN_PACKAGE_LIST=(
        ettercap-graphical
        forensics-all
        guymager
        hydra-gtk
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then
    # nothing for now
    true

  fi # Linux vs. MSYS
}

################################################################################
function CreateCommonLinuxConfig {
  if [[ -n $LINUX ]]; then

    unset CONFIRMATION
    read -p "Create missing common local config in home [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      touch "$HOME"/.hushlogin

      mkdir -p "$HOME/Desktop" \
               "$HOME/download" \
               "$HOME/media/music" \
               "$HOME/media/images" \
               "$HOME/media/video" \
               "$HOME/tmp" \
               "$LOCAL_BIN_PATH" \
               "$LOCAL_DATA_PATH"/bash-completion/completions

      [[ ! -f "$HOME"/.vimrc ]] && echo "set nocompatible" > "$HOME"/.vimrc

      if [[ ! -d "$HOME"/.ssh ]]; then
        mkdir "$HOME"/.ssh
        chmod 700 "$HOME"/.ssh
      fi

      dpkg -s thunar >/dev/null 2>&1 && xdg-mime default Thunar-folder-handler.desktop inode/directory application/x-gnome-saved-search
    fi

    if [[ -z $WSL ]]; then
      unset CONFIRMATION
      read -p "Setup user-dirs.dirs [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        cat <<EOX > "$LOCAL_CONFIG_PATH"/user-dirs.dirs
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/download"
XDG_TEMPLATES_DIR="$HOME/Documents/Templates"
XDG_PUBLICSHARE_DIR="$HOME/tmp"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/media/music"
XDG_PICTURES_DIR="$HOME/media/video"
XDG_VIDEOS_DIR="$HOME/media/images"
EOX
      fi

      if dpkg -s tilix >/dev/null 2>&1; then
        unset CONFIRMATION
        read -p "Configure Tilix [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          TILIX_CONFIG_B64="Wy9dCndhcm4tdnRlLWNvbmZpZy1pc3N1ZT1mYWxzZQpzaWRlYmFyLW9uLXJpZ2h0PXRydWUKCltrZXliaW5kaW5nc10Kd2luLXZpZXctc2lkZWJhcj0nTWVudScKCltwcm9maWxlcy8yYjdjNDA4MC0wZGRkLTQ2YzUtOGYyMy01NjNmZDNiYTc4OWRdCmZvcmVncm91bmQtY29sb3I9JyNGOEY4RjInCnZpc2libGUtbmFtZT0nRGVmYXVsdCcKcGFsZXR0ZT1bJyMyNzI4MjInLCAnI0Y5MjY3MicsICcjQTZFMjJFJywgJyNGNEJGNzUnLCAnIzY2RDlFRicsICcjQUU4MUZGJywgJyNBMUVGRTQnLCAnI0Y4RjhGMicsICcjNzU3MTVFJywgJyNGOTI2NzInLCAnI0E2RTIyRScsICcjRjRCRjc1JywgJyM2NkQ5RUYnLCAnI0FFODFGRicsICcjQTFFRkU0JywgJyNGOUY4RjUnXQpiYWRnZS1jb2xvci1zZXQ9ZmFsc2UKdXNlLXN5c3RlbS1mb250PWZhbHNlCmN1cnNvci1jb2xvcnMtc2V0PWZhbHNlCmhpZ2hsaWdodC1jb2xvcnMtc2V0PWZhbHNlCnVzZS10aGVtZS1jb2xvcnM9ZmFsc2UKYm9sZC1jb2xvci1zZXQ9ZmFsc2UKZm9udD0nSGFjayAxMicKdGVybWluYWwtYmVsbD0nbm9uZScKYmFja2dyb3VuZC1jb2xvcj0nIzI3MjgyMicK"
          echo "$TILIX_CONFIG_B64" | base64 -d | sed "s/Hack/$TILIX_FONT/g" > /tmp/tilixsetup.dconf
          dconf load /com/gexperts/Tilix/ < /tmp/tilixsetup.dconf
          rm -f /tmp/tilixsetup.dconf
        fi
      fi
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Create missing common local config in home [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      touch "$HOME"/.hushlogin

      mkdir -p "$HOME/tmp" \
               "$HOME/media" \
               "$LOCAL_BIN_PATH"

      if [[ -n $USERPROFILE ]]; then
        WIN_HOME="$(cygpath -u "$USERPROFILE")"

        [[ -d "$WIN_HOME"/Downloads ]] && \
          ln -vs "$WIN_HOME"/Downloads "$HOME"/download
        [[ -d "$WIN_HOME"/Documents ]] && \
          ln -vs "$WIN_HOME"/Documents "$HOME"/Documents
        [[ -d "$WIN_HOME"/Desktop ]] && \
          ln -vs "$WIN_HOME"/Desktop "$HOME"/Desktop
        [[ -d "$WIN_HOME"/Pictures ]] && \
          ln -vs "$WIN_HOME"/Pictures "$HOME"/media/images
        [[ -d "$WIN_HOME"/Music ]] && \
          ln -vs "$WIN_HOME"/Music "$HOME"/media/music
        [[ -d "$WIN_HOME"/Videos ]] && \
          ln -vs "$WIN_HOME"/Videos "$HOME"/media/video
      fi

      [[ ! -f "$HOME"/.vimrc ]] && echo "set nocompatible" > "$HOME"/.vimrc

      if [[ ! -d "$HOME"/.ssh ]]; then
        mkdir "$HOME"/.ssh
        chmod 700 "$HOME"/.ssh
      fi
    fi

  fi # Linux vs. MSYS
}

################################################################################
function InstallUserLocalFonts {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then
    unset CONFIRMATION
    read -p "Install user-local fonts [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      mkdir -p "$LOCAL_DATA_PATH"/fonts "$LOCAL_CONFIG_PATH"/fontconfig/conf.d

      LATEST_NERDFONT_RELEASE="$(_GitLatestRelease ryanoasis/nerd-fonts)"
      pushd "$LOCAL_DATA_PATH"/fonts >/dev/null 2>&1
      for NERDFONT in DejaVuSansMono FiraCode FiraMono Hack Incosolata LiberationMono SourceCodePro Ubuntu UbuntuMono; do
        curl -L -o ./$NERDFONT.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/$LATEST_NERDFONT_RELEASE/$NERDFONT.zip"
        unzip -o ./$NERDFONT.zip
      done
      rm -f "$LOCAL_DATA_PATH"/fonts/*Nerd*Windows*.ttf "$LOCAL_DATA_PATH"/fonts/*.zip "$LOCAL_DATA_PATH"/fonts/*Nerd*.otf
      popd >/dev/null 2>&1
      fc-cache -f -v
      if dpkg -s fonts-hack-ttf >/dev/null 2>&1 ; then
        $SUDO_CMD apt-get -y --purge remove fonts-hack-ttf
      fi
      TILIX_FONT="Hack Nerd Font Regular"
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Install user-local fonts [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add nerd-fonts
      scoop install nerd-fonts/Hack-NF
      scoop install nerd-fonts/Hack-NF-Mono
    fi

  fi # Linux vs. MSYS
}

################################################################################
function InstallUserLocalBinaries {
  if [[ -n $LINUX ]]; then
    unset CONFIRMATION
    read -p "Install user-local binaries/packages [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      mkdir -p "$LOCAL_BIN_PATH" "$LOCAL_DATA_PATH"/bash-completion/completions

      if [[ "$LINUX_ARCH" == "amd64" ]] && [[ -z $WSL ]]; then
        PCLOUD_URL="https://filedn.com/lqGgqyaOApSjKzN216iPGQf/Software/Linux/pcloud"
        curl -L "$PCLOUD_URL" > "$LOCAL_BIN_PATH"/pcloud
        chmod 755 "$LOCAL_BIN_PATH"/pcloud
      fi

      CROC_RELEASE="$(_GitLatestRelease schollz/croc | sed 's/^v//')"
      TMP_CLONE_DIR="$(mktemp -d)"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        if [[ "$LINUX_CPU" == "aarch64" ]]; then
          RELEASE_ARCH=ARM64
        else
          RELEASE_ARCH=ARM
        fi
      else
        RELEASE_ARCH=64bit
      fi
      curl -L "https://github.com/schollz/croc/releases/download/v${CROC_RELEASE}/croc_${CROC_RELEASE}_Linux-${RELEASE_ARCH}.tar.gz" | tar xvzf - -C "${TMP_CLONE_DIR}"
      cp -f "${TMP_CLONE_DIR}"/croc "$LOCAL_BIN_PATH"/croc
      cp -f "${TMP_CLONE_DIR}"/bash_autocomplete "$LOCAL_DATA_PATH"/bash-completion/completions/croc.bash
      chmod 755 "$LOCAL_BIN_PATH"/croc
      rm -rf "$TMP_CLONE_DIR"

      # curl -o "$LOCAL_BIN_PATH"/makesure -L "https://raw.githubusercontent.com/xonixx/makesure/main/makesure.awk"
      # chmod 755 "$LOCAL_BIN_PATH"/makesure

      GRON_RELEASE="$(_GitLatestRelease tomnomnom/gron | sed 's/^v//')"
      TMP_CLONE_DIR="$(mktemp -d)"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        if [[ "$LINUX_CPU" == "aarch64" ]]; then
          RELEASE_ARCH=arm64
        else
          RELEASE_ARCH=arm
        fi
      else
        RELEASE_ARCH=amd64
      fi
      curl -L "https://github.com/tomnomnom/gron/releases/download/v${GRON_RELEASE}/gron-linux-${RELEASE_ARCH}-${GRON_RELEASE}.tgz" | tar xvzf - -C "${TMP_CLONE_DIR}"
      cp -f "${TMP_CLONE_DIR}"/gron "$LOCAL_BIN_PATH"/gron
      chmod 755 "$LOCAL_BIN_PATH"/gron
      rm -rf "$TMP_CLONE_DIR"

      if [[ "$LINUX_ARCH" == "amd64" ]]; then
        SQ_RELEASE="$(_GitLatestRelease neilotoole/sq | sed 's/^v//')"
        TMP_CLONE_DIR="$(mktemp -d)"
        curl -L "https://github.com/neilotoole/sq/releases/download/v${SQ_RELEASE}/sq-linux-${LINUX_ARCH}.tar.gz" | tar xvzf - -C "${TMP_CLONE_DIR}"
        cp -f "${TMP_CLONE_DIR}"/sq "$LOCAL_BIN_PATH"/sq
        chmod 755 "$LOCAL_BIN_PATH"/sq
        rm -rf "$TMP_CLONE_DIR"
      fi

      STEPCLI_RELEASE="$(_GitLatestRelease smallstep/cli | sed 's/^v//')"
      TMP_CLONE_DIR="$(mktemp -d)"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        if [[ "$LINUX_CPU" == "aarch64" ]]; then
          RELEASE_ARCH=arm64
        elif [[ "$LINUX_CPU" == "armv6l" ]]; then
          RELEASE_ARCH=armv6
        else
          RELEASE_ARCH=armv7
        fi
      else
        RELEASE_ARCH=amd64
      fi
      curl -L "https://github.com/smallstep/cli/releases/download/v${STEPCLI_RELEASE}/step_linux_${STEPCLI_RELEASE}_${RELEASE_ARCH}.tar.gz" | tar xvzf - -C "${TMP_CLONE_DIR}" --strip-components 1
      cp -f "${TMP_CLONE_DIR}"/bin/step "$LOCAL_BIN_PATH"/step
      cp -f "${TMP_CLONE_DIR}"/autocomplete/bash_autocomplete "$LOCAL_DATA_PATH"/bash-completion/completions/step.bash
      chmod 755 "$LOCAL_BIN_PATH"/step
      rm -rf "$TMP_CLONE_DIR"

      TERMSHARK_RELEASE="$(_GitLatestRelease gcla/termshark | sed 's/^v//')"
      TMP_CLONE_DIR="$(mktemp -d)"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        if [[ "$LINUX_CPU" == "aarch64" ]]; then
          RELEASE_ARCH=arm64
        else
          RELEASE_ARCH=armv6
        fi
      else
        RELEASE_ARCH=x64
      fi
      curl -L "https://github.com/gcla/termshark/releases/download/v${TERMSHARK_RELEASE}/termshark_${TERMSHARK_RELEASE}_linux_${RELEASE_ARCH}.tar.gz" | tar xvzf - -C "${TMP_CLONE_DIR}" --strip-components 1
      cp -f "${TMP_CLONE_DIR}"/termshark "$LOCAL_BIN_PATH"/termshark
      chmod 755 "$LOCAL_BIN_PATH"/termshark
      rm -rf "$TMP_CLONE_DIR"

      SUPERCRONIC_RELEASE="$(_GitLatestRelease aptible/supercronic | sed 's/^v//')"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        if [[ "$LINUX_CPU" == "aarch64" ]]; then
          RELEASE_ARCH=arm64
        else
          RELEASE_ARCH=arm
        fi
      else
        RELEASE_ARCH=amd64
      fi
      curl -o "$LOCAL_BIN_PATH"/supercronic.new -L "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_RELEASE}/supercronic-linux-${RELEASE_ARCH}"
      chmod 755 "$LOCAL_BIN_PATH"/supercronic.new
      [[ -f "$LOCAL_BIN_PATH"/supercronic ]] && rm -f "$LOCAL_BIN_PATH"/supercronic
      mv "$LOCAL_BIN_PATH"/supercronic.new "$LOCAL_BIN_PATH"/supercronic

      BORINGPROXY_RELEASE="$(_GitLatestRelease boringproxy/boringproxy | sed 's/^v//')"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        if [[ "$LINUX_CPU" == "aarch64" ]]; then
          RELEASE_ARCH=arm64
        else
          RELEASE_ARCH=arm
        fi
      else
        RELEASE_ARCH=x86_64
      fi
      curl -o "$LOCAL_BIN_PATH"/boringproxy.new -L "https://github.com/boringproxy/boringproxy/releases/download/v${BORINGPROXY_RELEASE}/boringproxy-linux-${RELEASE_ARCH}"
      chmod 755 "$LOCAL_BIN_PATH"/boringproxy.new
      [[ -f "$LOCAL_BIN_PATH"/boringproxy ]] && rm -f "$LOCAL_BIN_PATH"/boringproxy
      mv "$LOCAL_BIN_PATH"/boringproxy.new "$LOCAL_BIN_PATH"/boringproxy

      TMP_CLONE_DIR="$(mktemp -d)"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        if [[ "$LINUX_CPU" == "aarch64" ]]; then
          RELEASE_ARCH=arm64
        else
          RELEASE_ARCH=arm
        fi
      else
        RELEASE_ARCH=amd64
      fi
      curl -o "${TMP_CLONE_DIR}"/ngrok.zip -L "https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-${RELEASE_ARCH}.zip"
      pushd "$TMP_CLONE_DIR" >/dev/null 2>&1
      unzip ./ngrok.zip
      chmod 755 ./ngrok
      cp -f ./ngrok "$LOCAL_BIN_PATH"/ngrok
      popd >/dev/null 2>&1
      rm -rf "$TMP_CLONE_DIR"

      if [[ "$LINUX_ARCH" == "amd64" ]]; then
        ASTREE_RELEASE="$(_GitLatestRelease jez/as-tree | sed 's/^v//')"
        TMP_CLONE_DIR="$(mktemp -d)"
        curl -o "${TMP_CLONE_DIR}"/as-tree.zip -L "https://github.com/jez/as-tree/releases/download/${ASTREE_RELEASE}/as-tree-${ASTREE_RELEASE}-linux.zip"
        pushd "$TMP_CLONE_DIR" >/dev/null 2>&1
        unzip ./as-tree.zip
        chmod 755 ./as-tree
        cp -f ./as-tree "$LOCAL_BIN_PATH"/as-tree
        popd >/dev/null 2>&1
        rm -rf "$TMP_CLONE_DIR"

        FFSEND_RELEASE="$(_GitLatestRelease timvisee/ffsend | sed 's/^v//')"
        TMP_CLONE_DIR="$(mktemp -d)"
        curl -o "${TMP_CLONE_DIR}"/ffsend -L "https://github.com/timvisee/ffsend/releases/download/v${FFSEND_RELEASE}/ffsend-v${FFSEND_RELEASE}-linux-x64-static"
        pushd "$TMP_CLONE_DIR" >/dev/null 2>&1
        chmod 755 ./ffsend
        cp -f ./ffsend "$LOCAL_BIN_PATH"/ffsend
        popd >/dev/null 2>&1
        rm -rf "$TMP_CLONE_DIR"

        DRA_RELEASE="$(_GitLatestRelease devmatteini/dra)"
        TMP_CLONE_DIR="$(mktemp -d)"
        curl -L "https://github.com/devmatteini/dra/releases/download/${DRA_RELEASE}/dra-${DRA_RELEASE}.tar.gz" | tar xvzf - -C "${TMP_CLONE_DIR}" --strip-components 1
        cp -f "${TMP_CLONE_DIR}"/dra "$LOCAL_BIN_PATH"/dra
        chmod 755 "$LOCAL_BIN_PATH"/dra
        rm -rf "$TMP_CLONE_DIR"
      fi
    fi

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then

    unset CONFIRMATION
    read -p "Install user-local binaries/packages [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      # nothing for now (scoop pretty much did this already)
      ( [[ -n $USERPROFILE ]] && \
          [[ -d "$(cygpath -u "$USERPROFILE")"/Downloads ]] && \
          pushd "$(cygpath -u "$USERPROFILE")"/Downloads >/dev/null 2>&1 ) || pushd . >/dev/null 2>&1

        curl -L -J -O 'https://launchpad.net/veracrypt/trunk/1.25.9/+download/VeraCrypt_Setup_x64_1.25.9.msi'
        curl -L -J -O 'https://github.com/Open-Shell/Open-Shell-Menu/releases/download/v4.4.160/OpenShellSetup_4_4_160.exe'

        echo "Some installers downloaded to \"$(pwd)\"" >&2
        popd >/dev/null 2>&1
    fi

  fi # Linux vs. MSYS
}

################################################################################
function SetupGroupsAndSudo {

  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    if [[ "$SCRIPT_USER" != "root" ]]; then

      # grant godlike power power
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
%netdev ALL=(root) NOPASSWD: /usr/local/bin/wwg.sh
%cryptkeeper ALL=(root) NOPASSWD:/sbin/cryptsetup
%cryptkeeper ALL=(root) NOPASSWD:/usr/bin/veracrypt
EOT
        $SUDO_CMD chmod 440 /etc/sudoers.d/power_groups
      fi # confirmation on group stuff
    fi # ! -f /etc/sudoers.d/power_groups

  elif [[ -n $MSYS ]] && [[ -n $HAS_SCOOP ]]; then
    scoop install main/sudo

  fi # Linux vs. MSYS
}

################################################################################
function SetupNICPrivs {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then
    # set capabilities for network capture
    unset CONFIRMATION
    read -p "Set capabilities for netdev users to sniff [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      EXE_LESS_CAP=(
        /opt/zeek/bin/capstats
        /opt/zeek/bin/zeek
        /sbin/ethtool
        /usr/bin/bro
        /usr/bin/capstats
        /usr/bin/dumpcap
        /usr/bin/ncat
        /usr/bin/openssl
        /usr/bin/socat
        /usr/bin/stunnel3
        /usr/bin/stunnel4
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
        /usr/sbin/tcpd
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
        /usr/sbin/inetd
        /usr/sbin/mausezahn
        /usr/sbin/netsniff-ng
        /usr/sbin/stenotype
        /usr/sbin/trafgen
      )
      for i in ${EXE_LESS_CAP[@]}; do
        [[ -e "$i" ]] && \
        $SUDO_CMD chown root:netdev "$i" && \
          $SUDO_CMD setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip CAP_NET_BIND_SERVICE+eip' "$i"
      done
      for i in ${EXE_MORE_CAP[@]}; do
        [[ -e "$i" ]] && \
        $SUDO_CMD chown root:netdev "$i" && \
          $SUDO_CMD setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip CAP_NET_BIND_SERVICE+eip CAP_IPC_LOCK+eip CAP_SYS_ADMIN+eip' "$i"
      done
    fi # setcap confirmation
  fi
}

################################################################################
function SetupFirewall {
  if [[ -n $LINUX ]] && [[ -z $WSL ]] && dpkg -s ufw >/dev/null 2>&1; then

    unset CONFIRMATION
    read -p "Enable/configure UFW (uncomplicated firewall) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      $SUDO_CMD sed -i "s/LOGLEVEL=.*/LOGLEVEL=off/" /etc/ufw/ufw.conf

      # ufw/docker
      UFWDOCKER=0
      if $SUDO_CMD docker info >/dev/null 2>&1 ; then
        read -p "Configure UFW/docker interaction and docker address pools? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then

          $SUDO_CMD sed -i 's/DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
          $SUDO_CMD sed -i "s/#net\/ipv4\/ip_forward=1/net\/ipv4\/ip_forward=1/" /etc/ufw/sysctl.conf

          cat <<EOF >> /tmp/docker-nat-rules.cfg
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING ! -o docker0 -s 172.27.0.0/16 -j MASQUERADE
COMMIT

EOF
          $SUDO_CMD cat /tmp/docker-nat-rules.cfg /etc/ufw/before.rules | $SUDO_CMD sponge /etc/ufw/before.rules
          rm -f /tmp/docker-nat-rules.cfg

          $SUDO_CMD mkdir -p /etc/docker/
          (cat /etc/docker/daemon.json 2>/dev/null || echo '{}') | jq '. + { "iptables": false }' | jq '. + { "default-address-pools": [ { "base": "172.27.0.0/16", "size": 24 } ] }' | $SUDO_CMD sponge /etc/docker/daemon.json

          UFWDOCKER=1
        fi # ufw/docker confirmation
      fi # ufw/docker check

      # enable firewall, disallow everything in except SSH/NTP
      $SUDO_CMD ufw enable
      $SUDO_CMD ufw default deny incoming
      $SUDO_CMD ufw default allow outgoing
      UFW_ALLOW_RULES=(
        ntp
        ssh
      )
      for i in ${UFW_ALLOW_RULES[@]}; do
        $SUDO_CMD ufw allow "$i"
      done

      (( $UFWDOCKER == 1 )) && ( ( $SUDO_CMD systemctl daemon-reload && $SUDO_CMD systemctl restart docker ) || true )

    fi # ufw confirmation

  fi
}

################################################################################
function SystemConfig {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then

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
        $SUDO_CMD sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\).*/\1"random.trust_cpu=on elevator=deadline cgroup_enable=memory swapaccount=1 cgroup.memory=nokmem"/' /etc/default/grub
        $SUDO_CMD update-grub
      fi # grub confirmation
    fi # grub check
  fi
}

################################################################################
function GueroSymlinks {
  if [[ -n $GUERO_GITHUB_PATH ]] && [[ -d "$GUERO_GITHUB_PATH" ]]; then
    unset CONFIRMATION
    read -p "Setup symlinks for dotfiles in \"$GUERO_GITHUB_PATH\" [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      mkdir -p "$LOCAL_BIN_PATH"

      [[ -r "$GUERO_GITHUB_PATH"/bash/"$SCRIPT_NAME" ]] && rm -vf "$LOCAL_BIN_PATH"/"$SCRIPT_NAME" && \
        ln -vrs "$GUERO_GITHUB_PATH"/bash/"$SCRIPT_NAME" "$LOCAL_BIN_PATH"/"$SCRIPT_NAME"

      [[ -r "$GUERO_GITHUB_PATH"/bash/rc ]] && rm -vf "$HOME"/.bashrc && \
        ln -vrs "$GUERO_GITHUB_PATH"/bash/rc "$HOME"/.bashrc

      [[ -r "$GUERO_GITHUB_PATH"/bash/aliases ]] && rm -vf "$HOME"/.bash_aliases && \
        ln -vrs "$GUERO_GITHUB_PATH"/bash/aliases "$HOME"/.bash_aliases

      [[ -r "$GUERO_GITHUB_PATH"/bash/functions ]] && rm -vf "$HOME"/.bash_functions && \
        ln -vrs "$GUERO_GITHUB_PATH"/bash/functions "$HOME"/.bash_functions

      [[ -d "$GUERO_GITHUB_PATH"/bash/rc.d ]] && rm -vf "$HOME"/.bashrc.d && \
        ln -vrs "$GUERO_GITHUB_PATH"/bash/rc.d "$HOME"/.bashrc.d

      [[ -r "$GUERO_GITHUB_PATH"/git/gitconfig ]] && rm -vf "$HOME"/.gitconfig && \
        ln -vrs "$GUERO_GITHUB_PATH"/git/gitconfig "$HOME"/.gitconfig

      [[ -r "$GUERO_GITHUB_PATH"/git/gitignore_global ]] && rm -vf "$HOME"/.gitignore_global && \
        ln -vrs "$GUERO_GITHUB_PATH"/git/gitignore_global "$HOME"/.gitignore_global

      [[ -r "$GUERO_GITHUB_PATH"/git/git_clone_all.sh ]] && rm -vf "$LOCAL_BIN_PATH"/git_clone_all.sh && \
        ln -vrs "$GUERO_GITHUB_PATH"/git/git_clone_all.sh "$LOCAL_BIN_PATH"/git_clone_all.sh

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/tmux/tmux.conf ]] && rm -vf "$HOME"/.tmux.conf && \
        ln -vrs "$GUERO_GITHUB_PATH"/linux/tmux/tmux.conf "$HOME"/.tmux.conf

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/xbindkeys/xbindkeysrc ]] && rm -vf "$HOME"/.xbindkeysrc && \
        ln -vrs "$GUERO_GITHUB_PATH"/linux/xbindkeys/xbindkeysrc "$HOME"/.xbindkeysrc

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/xxdiff/xxdiffrc ]] && rm -vf "$HOME"/.xxdiffrc && \
        ln -vrs "$GUERO_GITHUB_PATH"/linux/xxdiff/xxdiffrc "$HOME"/.xxdiffrc

      [[ -r "$GUERO_GITHUB_PATH"/gdb/gdbinit ]] && rm -vf "$HOME"/.gdbinit && \
        ln -vrs "$GUERO_GITHUB_PATH"/gdb/gdbinit "$HOME"/.gdbinit

      [[ -r "$GUERO_GITHUB_PATH"/gdb/cgdbrc ]] && mkdir -p "$HOME"/.cgdb && rm -vf "$HOME"/.cgdb/cgdbrc && \
        ln -vrs "$GUERO_GITHUB_PATH"/gdb/cgdbrc "$HOME"/.cgdb/cgdbrc

      [[ -r "$GUERO_GITHUB_PATH"/gdb/hexdump.py ]] && mkdir -p "$LOCAL_CONFIG_PATH"/gdb && rm -vf "$LOCAL_CONFIG_PATH"/gdb/hexdump.py && \
        ln -vrs "$GUERO_GITHUB_PATH"/gdb/hexdump.py "$LOCAL_CONFIG_PATH"/gdb/hexdump.py

      [[ ! -d "$LOCAL_CONFIG_PATH"/gdb/peda ]] && _GitClone https://github.com/longld/peda.git "$LOCAL_CONFIG_PATH"/gdb/peda

      if [[ -n $LINUX ]] && dpkg -s lxde-core >/dev/null 2>&1 && [[ -d "$GUERO_GITHUB_PATH"/linux/lxde-desktop.config ]]; then
        unset CONFIRMATION
        read -p "Setup symlinks for LXDE config [y/N]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-N}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          while IFS= read -d $'\0' -r CONFDIR; do
            DIRNAME="$(basename "$CONFDIR")"
            rm -vf "$LOCAL_CONFIG_PATH"/"$DIRNAME" && ln -vrs "$CONFDIR" "$LOCAL_CONFIG_PATH"/"$DIRNAME"
          done < <(find "$GUERO_GITHUB_PATH"/linux/lxde-desktop.config -mindepth 1 -maxdepth 1 -type d -print0)
        fi
      fi

      if [[ -n $LINUX ]] && dpkg -s xfce4 >/dev/null 2>&1 && [[ -d "$GUERO_GITHUB_PATH"/linux/xfce-desktop.config ]]; then
        unset CONFIRMATION
        read -p "Setup symlinks for XFCE config [y/N]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-N}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          while IFS= read -d $'\0' -r CONFDIR; do
            DIRNAME="$(basename "$CONFDIR")"
            rm -vf "$LOCAL_CONFIG_PATH"/"$DIRNAME" && ln -vrs "$CONFDIR" "$LOCAL_CONFIG_PATH"/"$DIRNAME"
          done < <(find "$GUERO_GITHUB_PATH"/linux/xfce-desktop.config -mindepth 1 -maxdepth 1 -type d -print0)
          XFCE_DCONF_CONFIG_B64="W29yZy9nbm9tZS9kZXNrdG9wL2ludGVyZmFjZV0KZ3RrLXRoZW1lPSdBZHdhaXRhLWRhcmsnCmljb24tdGhlbWU9J0Fkd2FpdGEnCgpbb3JnL2d0ay9zZXR0aW5ncy9jb2xvci1jaG9vc2VyXQpjdXN0b20tY29sb3JzPVsoMC4wODYyNzQ1MDk4MDM5MjE1NjcsIDAuMDg2Mjc0NTA5ODAzOTIxNTY3LCAwLjExMzcyNTQ5MDE5NjA3ODQzLCAxLjApLCAoMC41LCAwLjUsIDAuNSwgMS4wKV0Kc2VsZWN0ZWQtY29sb3I9KHRydWUsIDAuMDg2Mjc0NTA5ODAzOTIxNTY3LCAwLjA4NjI3NDUwOTgwMzkyMTU2NywgMC4xMTM3MjU0OTAxOTYwNzg0MywgMS4wKQoK"
          echo "$XFCE_DCONF_CONFIG_B64" | base64 -d > /tmp/xfce.dconf
          dconf load / < /tmp/xfce.dconf
          rm -f /tmp/xfce.dconf
        fi
      fi

      if [[ -n $LINUX ]] && [[ -d "$GUERO_GITHUB_PATH"/sublime ]]; then
        mkdir -p "$LOCAL_CONFIG_PATH"/sublime-text-3/Packages/User
        while IFS= read -d $'\0' -r CONFFILE; do
          FNAME="$(basename "$CONFFILE")"
          rm -vf "$LOCAL_CONFIG_PATH"/sublime-text-3/Packages/User/"$FNAME" && ln -vrs "$CONFFILE" "$LOCAL_CONFIG_PATH"/sublime-text-3/Packages/User/"$FNAME"
        done < <(find "$GUERO_GITHUB_PATH"/sublime -mindepth 1 -maxdepth 1 -type f -print0)
      fi

      LINKED_SCRIPTS=(
        pem_passwd.sh
        self_signed_key_gen.sh
        windems.sh
      )
      for i in ${LINKED_SCRIPTS[@]}; do
        rm -vf "$LOCAL_BIN_PATH"/"$i" && ln -vrs "$GUERO_GITHUB_PATH"/scripts/"$i" "$LOCAL_BIN_PATH"/
      done

      [[ -r "$GUERO_GITHUB_PATH"/bash/context-color/context-color ]] && rm -vf "$LOCAL_BIN_PATH"/context-color && \
        ln -vrs "$GUERO_GITHUB_PATH"/bash/context-color/context-color "$LOCAL_BIN_PATH"/context-color

    fi # dotfiles setup confirmation
  fi # dotfiles check for github checkout
}

################################################################################
function GueroDockerWrappers {
  unset CONFIRMATION
  read -p "Download mmguero's Docker image wrapper shell scripts [Y/n]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-Y}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    mkdir -p "$LOCAL_BIN_PATH"
    pushd "$LOCAL_BIN_PATH" >/dev/null 2>&1
    WRAPPER_SH_URLS=(
      https://raw.githubusercontent.com/mmguero/cleanvid/main/docker/cleanvid-docker.sh
      https://raw.githubusercontent.com/mmguero/docker/master/capa/capa-docker.sh
      https://raw.githubusercontent.com/mmguero/docker/master/yt-dlp/yt-dlp-docker.sh
      https://raw.githubusercontent.com/mmguero/docker/master/gimp/gimp-docker.sh
      https://github.com/idaholab/network-architecture-verification-and-validation/blob/develop/docker/navv-docker.sh
      https://raw.githubusercontent.com/mmguero/monkeyplug/main/docker/monkeyplug-docker.sh
      https://raw.githubusercontent.com/mmguero/montag/main/docker/montag-docker.sh
      https://raw.githubusercontent.com/mmguero/zeek-docker/main/zeek-docker.sh
    )
    for i in ${WRAPPER_SH_URLS[@]}; do
      rm -f "$(basename "$i")" && \
        curl -f -L -O -J "$i" && \
        chmod 755 "$(basename "$i")"
    done
    popd >/dev/null 2>&1
  fi # confirmation
}

################################################################################
# "main"

# in case we've already got some envs set up to use
_EnvSetup

# get a list of all the "public" functions (not starting with _)
FUNCTIONS=($(declare -F | awk '{print $NF}' | sort | egrep -v "^_"))

# present the menu to our customer and get their selection
printf "%s\t%s\n" "0" "ALL"
for i in "${!FUNCTIONS[@]}"; do
  ((IPLUS=i+1))
  printf "%s\t%s\n" "$IPLUS" "${FUNCTIONS[$i]}"
done
echo -n "Operation:" >&2
read USER_FUNCTION_IDX

if (( $USER_FUNCTION_IDX == 0 )); then
  # ALL: do everything, in order
  SetupMacOSBrew
  InstallEssentialPackages
  InstallEnvs
  _EnvSetup
  SetupAptSources
  InstallDocker
  DockerPullImages
  InstallVirtualization
  InstallCommonPackages
  InstallCommonPackagesGUI
  InstallCommonPackagesMedia
  InstallCommonPackagesNetworking
  InstallCommonPackagesNetworkingGUI
  InstallCommonPackagesForensics
  InstallCommonPackagesForensicsGUI
  CreateCommonLinuxConfig
  InstallEnvPackages
  InstallUserLocalFonts
  InstallUserLocalBinaries
  SetupGroupsAndSudo
  SetupNICPrivs
  SetupFirewall
  SystemConfig
  GueroSymlinks

elif (( $USER_FUNCTION_IDX > 0 )) && (( $USER_FUNCTION_IDX <= "${#FUNCTIONS[@]}" )); then
  # execute one function, à la carte
  USER_FUNCTION="${FUNCTIONS[((USER_FUNCTION_IDX-1))]}"
  echo $USER_FUNCTION
  $USER_FUNCTION

else
  # some people just want to watch the world burn
  echo "Invalid operation selected" >&2
  exit 1;
fi
