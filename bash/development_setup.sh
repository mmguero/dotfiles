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
CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}

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
  difftastic
  direnv
  fd
  fzf
  ghorg
  packer
  peco
  jq
  rclone
  ripgrep
  sops
  sopstool
  sqlite
  starship
  step
  stern
  tmux
  viddy
  websocat
  wtfutil
  xh
  yq
  yj
)

###################################################################################
# determine OS
unset MACOS
unset LINUX
unset WSL
unset HAS_SCOOP
unset LINUX_DISTRO
unset LINUX_RELEASE
unset LINUX_RELEASE_NUMBER
unset LINUX_ARCH
unset LINUX_CPU
unset LINUX_BACKPORTS_REPO_APT_FLAG

if [[ $(uname -s) = 'Darwin' ]]; then
  export MACOS=0

elif [[ -n $MSYSTEM ]]; then
  command -v cygpath >/dev/null 2>&1 && \
    [[ -n $USERPROFILE ]] && \
    [[ -d "$(cygpath -u "$USERPROFILE")"/scoop/shims ]] && \
    export PATH="$(cygpath -u $USERPROFILE)"/scoop/shims:"$PATH"
  command -v scoop >/dev/null 2>&1 && export HAS_SCOOP=0
  export MSYS=winsymlinks:nativestrict

else
  if grep -q Microsoft /proc/version; then
    export WSL=0
  fi
  export LINUX=0
  if command -v lsb_release >/dev/null 2>&1 ; then
    LINUX_DISTRO="$(lsb_release -is)"
    LINUX_RELEASE="$(lsb_release -cs)"
    LINUX_RELEASE_NUMBER="$(lsb_release -rs)"
  else
    if [[ -r '/etc/redhat-release' ]]; then
      RELEASE_FILE='/etc/redhat-release'
    elif [[ -r '/etc/issue' ]]; then
      RELEASE_FILE='/etc/issue'
    else
      unset RELEASE_FILE
    fi
    if [[ -n "$RELEASE_FILE" ]]; then
      LINUX_DISTRO="$( ( awk '{print $1}' < "$RELEASE_FILE" ) | head -n 1 )"
      if [[ "$LINUX_DISTRO" == "Ubuntu" ]]; then
        LINUX_RELEASE_NUMBER="$( ( awk '{print $2}' < "$RELEASE_FILE" ) | head -n 1 )"
      elif [[ "$LINUX_DISTRO" == "Debian" ]]; then
        LINUX_RELEASE_NUMBER="$( ( awk '{print $3}' < "$RELEASE_FILE" ) | head -n 1 )"
      fi
    fi
  fi
fi

# determine user and/or if we need to use sudo to install packages
if [[ -n $MACOS ]]; then
  SCRIPT_USER="$(whoami)"
  SUDO_CMD=""

elif [[ -n $MSYSTEM ]]; then
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
function _AptUpdate {
  if command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get update -qq >/dev/null 2>&1
    if [[ -n "$LINUX_RELEASE" ]]; then
      LINUX_BACKPORTS_REPO_APT_FLAG="-t $($SUDO_CMD apt-cache policy | grep -o "$LINUX_RELEASE-backports" | sort -u | head -n 1)"
    fi
  fi
}

###################################################################################
# convenience function for installing curl/git/jq/moreutils for cloning/downloading
function InstallEssentialPackages {
  if command -v curl >/dev/null 2>&1 && \
     command -v git >/dev/null 2>&1 && \
     command -v jq >/dev/null 2>&1 && \
     command -v sponge >/dev/null 2>&1 && \
     command -v unzip >/dev/null 2>&1; then
    echo "\"curl\", \"git\", \"jq\", \"moreutils\" and  \"unzip\" are already installed!" >&2
  else
    echo "Installing curl, git, jq, moreutils and unzip..." >&2
    if [[ -n $MACOS ]]; then
      brew install git jq moreutils unzip # since Jaguar curl is already installed in MacOS
    elif [[ -n $MSYSTEM ]]; then
      [[ -n $HAS_SCOOP ]] && scoop install main/curl main/git main/jq main/unzip || pacman --noconfirm -Sy curl git unzip ${MINGW_PACKAGE_PREFIX}-jq
      pacman --noconfirm -Sy moreutils
    elif [[ -n $LINUX ]]; then
      _AptUpdate
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y curl git jq moreutils unzip
    fi
  fi

  # fetch will be used to download other release/tag assets from GitHub
  if [[ ! -x "$LOCAL_BIN_PATH"/fetch ]]; then
    TMP_CLONE_DIR="$(mktemp -d)"
    pushd "$TMP_CLONE_DIR" >/dev/null 2>&1
    FETCH_ALT_URL=
    FETCH_BIN_EXT=
    if [[ -n $MSYSTEM ]]; then
      FETCH_URL="https://github.com/gruntwork-io/fetch/releases/latest/download/fetch_windows_amd64.exe"
      FETCH_BIN_EXT=".exe"
    elif [[ $DEB_ARCH == arm* ]]; then
      if [[ $LINUX_CPU == aarch64 ]]; then
        FETCH_URL="https://github.com/gruntwork-io/fetch/releases/latest/download/fetch_linux_arm64"
      else
        # todo
        FETCH_URL=
      fi
    else
      FETCH_URL="https://github.com/gruntwork-io/fetch/releases/latest/download/fetch_linux_amd64"
      FETCH_ALT_URL="https://filedn.com/lqGgqyaOApSjKzN216iPGQf/Software/Linux/fetch_linux_amd64"
    fi
    curl -fsSL -o ./"fetch${FETCH_BIN_EXT}" "$FETCH_URL"
    chmod 755 ./"fetch${FETCH_BIN_EXT}"
    if ./"fetch${FETCH_BIN_EXT}" --version >/dev/null 2>&1; then
      cp -f ./"fetch${FETCH_BIN_EXT}" "$LOCAL_BIN_PATH"/"fetch${FETCH_BIN_EXT}"
    elif [[ -n "$FETCH_ALT_URL" ]]; then
      curl -fsSL -o "$LOCAL_BIN_PATH"/"fetch${FETCH_BIN_EXT}" "$FETCH_URL"
      chmod 755 "$LOCAL_BIN_PATH"/"fetch${FETCH_BIN_EXT}"
    fi
    popd >/dev/null 2>&1
    rm -rf "$TMP_CLONE_DIR"
  fi

}

###################################################################################
function _GitClone {
  git clone --depth=1 --single-branch --recurse-submodules --shallow-submodules --no-tags "$@"
}

###################################################################################
function _GitLatestRelease {
  if [[ -n "$1" ]]; then
    GITHUB_API_CURL_ARGS=()
    GITHUB_API_CURL_ARGS+=( -fsSL )
    GITHUB_API_CURL_ARGS+=( -H )
    GITHUB_API_CURL_ARGS+=( "Accept: application/vnd.github.v3+json" )
    [[ -n "$GITHUB_TOKEN" ]] && \
      GITHUB_API_CURL_ARGS+=( -H ) && \
      GITHUB_API_CURL_ARGS+=( "Authorization: token $GITHUB_TOKEN" )
    (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases/latest" | jq '.tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
      (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases" | jq '.[0].tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
      echo unknown
  else
    echo unknown>&2
  fi
}

###################################################################################
# function to set up paths and init things after env installations
function _EnvSetup {
  if [[ -z $MSYSTEM ]]; then

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
# _DownloadViaFetch
function _DownloadViaFetch {
  DOWNLOAD_SPEC="$1"
  REPO="$(echo "$DOWNLOAD_SPEC" | cut -d'|' -f1)"
  [[ -z "$GITHUB_OAUTH_TOKEN" ]] && [[ -n "$GITHUB_TOKEN" ]] && export GITHUB_OAUTH_TOKEN="$GITHUB_TOKEN"
  ASSET_REGEX="$(echo "$DOWNLOAD_SPEC" | cut -d'|' -f2)"
  OUTPUT_FILE="$(echo "$DOWNLOAD_SPEC" | cut -d'|' -f3)"
  OUTPUT_FILE_PERMS="$(echo "$DOWNLOAD_SPEC" | cut -d'|' -f4)"
  echo "" >&2
  echo "Downloading asset for $REPO..." >&2
  FETCH_DIR="$(mktemp -d)"
  [[ -n $MSYSTEM ]] && FETCH_BIN_EXT=".exe" || FETCH_BIN_EXT=
  "$LOCAL_BIN_PATH"/"fetch${FETCH_BIN_EXT}" --progress --log-level warn \
    --repo="$REPO" \
    --tag=">=0.0.0" \
    --release-asset="$ASSET_REGEX" \
    "$FETCH_DIR"
  mv "$FETCH_DIR"/* "$OUTPUT_FILE"
  rm -rf "$FETCH_DIR"
  if [[ -f "$OUTPUT_FILE" ]]; then
    chmod "${OUTPUT_FILE_PERMS:-644}" "$OUTPUT_FILE"
    touch -m "$OUTPUT_FILE"
    if [[ "$OUTPUT_FILE" == *.tar.gz ]] || [[ "$OUTPUT_FILE" == *.tgz ]]; then
      UNPACK_DIR="$(mktemp -d)"
      tar xzf "$OUTPUT_FILE" -C "$UNPACK_DIR"
    elif [[ "$OUTPUT_FILE" == *.tar.xz ]] || [[ "$OUTPUT_FILE" == *.xz ]]; then
      UNPACK_DIR="$(mktemp -d)"
      tar xJf "$OUTPUT_FILE" -C "$UNPACK_DIR" --strip-components 1
    elif [[ "$OUTPUT_FILE" == *.zip ]]; then
      UNPACK_DIR="$(mktemp -d)"
      unzip -q "$OUTPUT_FILE" -d "$UNPACK_DIR"
    fi
    if [[ -d "$UNPACK_DIR" ]]; then
      find "$UNPACK_DIR" -type f -exec touch -m "{}" \;
      find "$UNPACK_DIR" -type f -exec file --mime-type "{}" \; | \
        grep -P ":\s+application/.*executable" | \
        cut -d: -f 1 | xargs -I XXX -r mv "XXX" "$LOCAL_BIN_PATH"/
      rm -rf "$UNPACK_DIR" "$OUTPUT_FILE"
    fi
  fi
  echo >&2
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
  if [[ -n $MSYSTEM ]]; then

    # TODO
    echo "todo" >&2
  fi # MSYS check
}

################################################################################
# envs (via asdf)
function InstallEnvs {
  if [[ -z $MSYSTEM ]]; then
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

        unset CONFIRMATION
        read -p "Update all installed envs [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          ASDF_AUTO_UPDATE=true
        else
          ASDF_AUTO_UPDATE=false
        fi

        for i in ${ENV_LIST[@]}; do
          if ! ( asdf plugin list | grep -q "$i" ) >/dev/null 2>&1 ; then
            if ! "$ASDF_AUTO_UPDATE"; then
              unset CONFIRMATION
              read -p "\"$i\" is not installed, attempt to install it [y/N]? " CONFIRMATION
              CONFIRMATION=${CONFIRMATION:-N}
              if [[ $CONFIRMATION =~ ^[Yy] ]]; then
                asdf plugin add "$i" && ENVS_INSTALLED[$i]=true
              fi
            fi
          else
            if ! "$ASDF_AUTO_UPDATE"; then
              unset CONFIRMATION
              read -p "\"$i\" is already installed, attempt to update it [Y/n]? " CONFIRMATION
              CONFIRMATION=${CONFIRMATION:-Y}
              if [[ $CONFIRMATION =~ ^[Yy] ]]; then
                ENVS_INSTALLED[$i]=true
              fi
            else
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
          libfribidi-dev \
          liblzma-dev \
          libncurses5-dev \
          libreadline-dev \
          libsqlite3-dev \
          libssl-dev \
          libxml2-dev \
          libxmlsec1-dev \
          llvm \
          make \
          tk-dev \
          wget \
          xz-utils \
          zlib1g-dev
      fi
    fi

    # ruby (build deps)
    if [[ ${ENVS_INSTALLED[ruby]} = 'true' ]]; then
      if [[ -n $LINUX ]]; then
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
          build-essential \
          libyaml-dev
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
          make
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

    if [[ ${ENVS_INSTALLED[python]} = 'true' ]] && python3 -m pip -V >/dev/null 2>&1; then
      python3 -m pip install -U pip
      python3 -m pip install -U setuptools
      python3 -m pip install -U wheel
      asdf reshim python
    fi
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
      python3 -m pip install -U pip
      python3 -m pip install -U setuptools
      python3 -m pip install -U wheel
      asdf reshim python
      python3 -m pip install -U \
        arrow \
        black \
        colorama \
        colored \
        Cython \
        dateparser \
        dataset \
        defopt \
        dtrx \
        entrypoint2 \
        git+https://github.com/badele/gitcheck.git \
        git-up \
        humanhash3 \
        more-itertools \
        mmguero \
        ordered-set \
        patool \
        psutil \
        py-cui \
        pyinputplus \
        python-dateutil \
        python-dotenv \
        python-magic \
        python-slugify \
        pythondialog \
        pyunpack \
        pyyaml \
        rich \
        ruamel.yaml \
        snoop \
        stackprinter \
        textual \
        tqdm \
        typer[all]

      if [[ -n $LINUX ]] && [[ -z $WSL ]]; then
        python3 -m pip install -U \
          pyinotify \
          sh
      fi
    fi

    if ruby -S gem -v >/dev/null 2>&1; then
      ruby -S gem install \
        openssl
      ruby -S gem install \
        faraday \
        lru_redux \
        fuzzy-string-match \
        stringex
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

    # sources.list.d and preferences.d entries for this release
    if [[ -n $GUERO_GITHUB_PATH ]] && [[ -d /etc/apt/sources.list.d ]] && [[ -d "$GUERO_GITHUB_PATH/linux/apt/sources.list.d/$LINUX_RELEASE" ]]; then
      unset CONFIRMATION
      read -p "Install sources.list.d entries for $LINUX_RELEASE [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        $SUDO_CMD cp -iv "$GUERO_GITHUB_PATH/linux/apt/sources.list.d/$LINUX_RELEASE"/* /etc/apt/sources.list.d/
        InstallEssentialPackages
        command -v gpg >/dev/null 2>&1 || \
          DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y --no-install-recommends gpg
        GPG_KEY_URLS=(
          "https://download.docker.com/linux/debian/gpg|/usr/share/keyrings/docker-archive-keyring.gpg"
          "https://download.sublimetext.com/sublimehq-pub.gpg|/usr/share/keyrings/sublimetext-keyring.gpg"
          "https://packages.microsoft.com/keys/microsoft.asc|/usr/share/keyrings/microsoft.gpg"
          "https://build.opensuse.org/projects/home:alvistack/signing_keys/download?kind=gpg|/usr/share/keyrings/home_alvistack.gpg"
          "https://packages.fluentbit.io/fluentbit.key|/usr/share/keyrings/fluentbit-keyring.gpg"
          "deb:fasttrack-archive-keyring"
        )
        for i in ${GPG_KEY_URLS[@]}; do
          SOURCE_URL="$(echo "$i" | cut -d'|' -f1)"
          OUTPUT_FILE="$(echo "$i" | cut -d'|' -f2)"
          if [[ $SOURCE_URL == deb:* ]]; then
            DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$(echo "$SOURCE_URL" | sed "s/^deb://")"
          else
            curl -sSL "$SOURCE_URL" | gpg --dearmor | $SUDO_CMD tee $OUTPUT_FILE >/dev/null
          fi
        done
      fi
    fi
    if [[ -n $GUERO_GITHUB_PATH ]] && [[ -d /etc/apt/preferences.d ]] && [[ -d "$GUERO_GITHUB_PATH/linux/apt/preferences.d/$LINUX_RELEASE" ]]; then
      unset CONFIRMATION
      read -p "Install preferences.d entries for $LINUX_RELEASE [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        $SUDO_CMD cp -iv "$GUERO_GITHUB_PATH/linux/apt/preferences.d/$LINUX_RELEASE"/* /etc/apt/preferences.d/
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
    if ! command -v docker >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "Attempt to install docker [Y/n]? " CONFIRMATION
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
          $SUDO_CMD add-apt-repository -y \
             "deb [arch=$LINUX_ARCH] https://download.docker.com/linux/ubuntu \
             $LINUX_RELEASE \
             stable"
        elif [[ "$LINUX_DISTRO" == "Raspbian" ]]; then
          $SUDO_CMD add-apt-repository -y \
             "deb [arch=$LINUX_ARCH] https://download.docker.com/linux/raspbian \
             $LINUX_RELEASE \
             stable"
        elif [[ "$LINUX_DISTRO" == "Debian" ]]; then
          $SUDO_CMD add-apt-repository -y \
             "deb [arch=$LINUX_ARCH] https://download.docker.com/linux/debian \
             $LINUX_RELEASE \
             stable"
        fi

        _AptUpdate
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

    unset CONFIRMATION
    read -p "Install distrobox [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && \
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- -p "$LOCAL_BIN_PATH"

  fi # MacOS vs. Linux for docker
}

################################################################################
function InstallKubernetes {

  unset CONFIRMATION
  read -p "Install k3sup [y/N]? " CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-N}
  if [[ $CONFIRMATION =~ ^[Yy] ]]; then
    curl -sLS https://get.k3sup.dev | sed "s@/usr/local/bin@$LOCAL_BIN_PATH@g"| sh -
  fi

  if [[ -n $MACOS ]]; then

    unset CONFIRMATION
    read -p "Install kubernetes-cli [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && brew install kubernetes-cli

    unset CONFIRMATION
    read -p "Install Helm [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && brew install helm

  elif [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    unset CONFIRMATION
    read -p "Install K3s [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      curl -sfL https://get.k3s.io | sh -

    else
      unset CONFIRMATION
      read -p "Install kubernetes-kubectl [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y kubernetes-kubectl
      fi
    fi # k3s/kubernetes-kubectl confirmation

    unset CONFIRMATION
    read -p "Install Helm [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      HELM_RELEASE="$(_GitLatestRelease helm/helm)"
      if [[ "$LINUX_ARCH" =~ ^arm ]]; then
        [[ "$LINUX_CPU" == "aarch64" ]] && HELM_ARCH=arm64 || HELM_ARCH=arm
      else
        HELM_ARCH=amd64
      fi
      HELM_URL="https://get.helm.sh/helm-${HELM_RELEASE}-linux-${HELM_ARCH}.tar.gz"
      TMP_CLONE_DIR="$(mktemp -d)"
      curl -sSL "$HELM_URL" | tar xzf - -C "${TMP_CLONE_DIR}" --strip-components 1
      cp -f "${TMP_CLONE_DIR}"/helm "$LOCAL_BIN_PATH"/helm
      chmod 755 "$LOCAL_BIN_PATH"/helm
      rm -rf "$TMP_CLONE_DIR"
    fi # helm confirmation

  fi # MacOS vs. Linux for docker

  _EnvSetup
  if command -v kubectl >/dev/null 2>&1 && command -v asdf >/dev/null 2>&1; then
    for UTIL in stern kubectx; do
      unset CONFIRMATION
      read -p "Install $UTIL (via asdf) [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        asdf plugin update $UTIL
        asdf install $UTIL latest
        asdf global $UTIL latest
        asdf reshim $UTIL
      fi
    done
  fi
}

################################################################################
function InstallContainerCompose {

  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    if command -v docker >/dev/null 2>&1 ; then
      # install docker-compose, if needed
      if ! docker-compose version >/dev/null 2>&1 ; then
        unset CONFIRMATION
        read -p "\"docker-compose version\" failed, attempt to install docker-compose [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then

          DOCKER_COMPOSE_BIN=/usr/libexec/docker/cli-plugins/docker-compose
          DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
          $SUDO_CMD curl -L -o "$DOCKER_COMPOSE_BIN" "$DOCKER_COMPOSE_URL"
          $SUDO_CMD chmod +x "$DOCKER_COMPOSE_BIN"
          if "$DOCKER_COMPOSE_BIN" version >/dev/null 2>&1 ; then
            $SUDO_CMD ln -s -r -f "$DOCKER_COMPOSE_BIN" /usr/local/bin/docker-compose
          else
            echo "Installing docker-compose failed" >&2
            exit 1
          fi

        fi # docker-compose install confirmation check
      else
        echo "\"docker-compose\" is already installed!" >&2
      fi # docker-compose install check
    fi

    if command -v podman >/dev/null 2>&1 && \
       python3 -m pip -V >/dev/null 2>&1; then
      # install podman-compose, if needed
      if ! podman-compose version >/dev/null 2>&1 ; then
        unset CONFIRMATION
        read -p "\"podman-compose version\" failed, attempt to install podman-compose [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          python3 -m pip install -U podman-compose
        fi # podman-compose install confirmation check
      else
        echo "\"podman-compose\" is already installed!" >&2
      fi # podman-compose install check
    fi

  fi
}

################################################################################
function DockerPullImages {
  if command -v ${CONTAINER_ENGINE} >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (Linux distributions) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        alpine:latest
        amazonlinux:2023
        debian:stable-slim
        debian:bookworm-slim
        bitnami/minideb:latest
        ghcr.io/mmguero/debian:latest
        ubuntu:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull images confirmation

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (media) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/cleanvid:latest
        ghcr.io/mmguero/lossless-cut:latest
        ghcr.io/mmguero/montag:latest
        ghcr.io/mmguero/monkeyplug:small
        jess/spotify:latest
        mwader/static-ffmpeg:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull media images confirmation

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (web services) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/net-clients:latest
        ghcr.io/mmguero/nginx-ldap:latest
        ghcr.io/mmguero/stunnel:latest
        ghcr.io/mmguero/tunneler:latest
        ghcr.io/mmguero/wireproxy:latest
        haugene/transmission-openvpn:latest
        nginx:latest
        osminogin/tor-simple:latest
        traefik/whoami:latest
        traefik:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull web images confirmation

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (web browsers) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        andrewmackrodt/chromium-x11:latest
        fathyb/carbonyl:latest
        ghcr.io/mmguero/firefox:latest
        ghcr.io/mmguero/net-clients:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull web images confirmation

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (office) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        lscr.io/linuxserver/libreoffice:latest
        ghcr.io/mmguero/gimp:LATEST
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull office confirmation

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (desktop environment) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/xfce-base:latest
        ghcr.io/mmguero/xfce:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull desktop environment

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (deblive) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/deblive:latest
        tianon/qemu:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull desktop environment

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (communication) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/mattermost:latest
        ghcr.io/mmguero/mirotalk:latest
        ghcr.io/mmguero/postgres:latest
        ghcr.io/mmguero/signal:latest
        ghcr.io/mmguero/teams:latest
        mdouchement/zoom-us:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull communication images confirmation

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (forensics) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        ghcr.io/mmguero/capa:latest
        ghcr.io/mmguero/zeek:latest
        ghcr.io/cisagov/network-architecture-verification-and-validation
        mpepping/cyberchef:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull forensics images confirmation

    unset CONFIRMATION
    read -p "Pull common ${CONTAINER_ENGINE} images (docker) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DOCKER_IMAGES=(
        alpine/dfimage:latest
        hello-world:latest
        nate/dockviz:latest
        wagoodman/dive:latest
      )
      for i in ${DOCKER_IMAGES[@]}; do
        ${CONTAINER_ENGINE} pull "$i"
      done
    fi # pull docker images confirmation

  fi # docker is there
}

################################################################################
function InstallPodman {
  if [[ -n $MACOS ]]; then

    # install podman, if needed
    if ! brew list --cask --versions podman >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "\"podman\" cask is not installed, attempt to install podman via brew [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        echo "Installing Podman..." >&2
        brew install podman
        echo "Installed Podman." >&2
        echo "Please modify settings as needed: https://github.com/containers/podman/blob/main/docs/tutorials/mac_experimental.md" >&2
      fi # podman install confirmation check
    else
      echo "\"podman\" is already installed!" >&2
    fi # podman install check

  elif [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    # install podman, if needed
    if ! command -v podman >/dev/null 2>&1 ; then
      unset CONFIRMATION
      read -p "\"podman info\" failed, attempt to install podman [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then

        InstallEssentialPackages

        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
                                                   apt-transport-https \
                                                   ca-certificates \
                                                   curl \
                                                   gnupg2 \
                                                   software-properties-common

        echo "Installing Podman..." >&2
        curl -sSL "https://build.opensuse.org/projects/home:alvistack/signing_keys/download?kind=gpg" | gpg --dearmor | $SUDO_CMD tee /usr/share/keyrings/home_alvistack.gpg >/dev/null
        if [[ "$LINUX_DISTRO" == "Ubuntu" ]]; then
          $SUDO_CMD add-apt-repository -y \
             "deb [signed-by=/usr/share/keyrings/home_alvistack.gpg] http://download.opensuse.org/repositories/home:/alvistack/xUbuntu_${LINUX_RELEASE_NUMBER}/ /"
        elif [[ "$LINUX_DISTRO" == "Debian" ]]; then
          $SUDO_CMD add-apt-repository -y \
             "deb  [signed-by=/usr/share/keyrings/home_alvistack.gpg] http://ftp.gwdg.de/pub/opensuse/repositories/home:/alvistack/Debian_${LINUX_RELEASE_NUMBER}/ /"
        fi

        _AptUpdate
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
          buildah \
          catatonit \
          crun \
          fuse-overlayfs \
          podman \
          podman-aardvark-dns \
          python3-podman-compose \
          podman-netavark \
          slirp4netns \
          uidmap

        dpkg -s cockpit >/dev/null 2>&1 && \
          DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y cockpit-podman

        # slightly bump a few privileges for non-privileged user to make life with podman better:
        # - unprivileged user namespaces
        # - bind to ports >= 80
        # - allow overlay2 storage driver in userspace
        # - cgroup settings for rootless containers
        # - set subuid/subgid ranges for user
        # - enable loginctl enable-linger for user (to allow user-level systemd services)
        # - add user to systemd-journal

        if [[ -r /etc/sysctl.conf ]]; then
          if ! grep -q unprivileged_userns_clone /etc/sysctl.conf; then
          $SUDO_CMD tee -a /etc/sysctl.conf > /dev/null <<'EOT'
# allow unprivileged user namespaces
kernel.unprivileged_userns_clone=1
EOT
          fi
          if ! grep -q ip_unprivileged_port_start /etc/sysctl.conf; then
          $SUDO_CMD tee -a /etc/sysctl.conf > /dev/null <<'EOT'
# allow lower unprivileged port bind
net.ipv4.ip_unprivileged_port_start=80
EOT
          fi
        elif [[ -d /etc/sysctl.d/ ]]; then
          if ! grep -q unprivileged_userns_clone /etc/sysctl.d/*; then
          $SUDO_CMD tee -a /etc/sysctl.d/80_userns.conf > /dev/null <<'EOT'
# allow unprivileged user namespaces
kernel.unprivileged_userns_clone=1
EOT
          fi
          if ! grep -q ip_unprivileged_port_start /etc/sysctl.d/*; then
          $SUDO_CMD tee -a /etc/sysctl.d/80_lowport.conf > /dev/null <<'EOT'
# allow lower unprivileged port bind
net.ipv4.ip_unprivileged_port_start=80
EOT
          fi
        fi

        $SUDO_CMD mkdir -p /etc/modprobe.d
        echo "options overlay permit_mounts_in_userns=1 metacopy=off redirect_dir=off" | $SUDO_CMD tee /etc/modprobe.d/podman.conf

        if [[ -d /etc/systemd/system ]]; then
          $SUDO_CMD mkdir -p /etc/systemd/system/user@.service.d
          echo -e "[Service]\\nDelegate=cpu cpuset io memory pids" | $SUDO_CMD tee /etc/systemd/system/user@.service.d/delegate.conf
        fi

        $SUDO_CMD touch /etc/subuid
        $SUDO_CMD touch /etc/subgid
        if ! grep --quiet "$SCRIPT_USER" /etc/subuid; then
          $SUDO_CMD usermod --add-subuids 200000-265535 "$SCRIPT_USER"
        fi
        if ! grep --quiet "$SCRIPT_USER" /etc/subgid; then
          $SUDO_CMD usermod --add-subgids 200000-265535 "$SCRIPT_USER"
        fi

        $SUDO_CMD loginctl enable-linger "$SCRIPT_USER"
        $SUDO_CMD usermod -a -G systemd-journal "$SCRIPT_USER"

        unset CONFIRMATION
        read -p "Enable and start podman socket service with \"systemctl --user\" [y/N]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-N}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          systemctl --user enable podman.service
          systemctl --user start podman.service
        fi # enable podman socket check

      fi # podman install confirmation check

    else
      echo "\"podman\" is already installed!" >&2
    fi # podman install check

  fi # MacOS vs. Linux for podman
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

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then

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

    _AptUpdate

    # virtualbox or kvm
    unset CONFIRMATION
    read -p "Install kvm/libvirt/qemu [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y --no-install-recommends \
        binfmt-support \
        ebtables \
        libguestfs-tools \
        libvirt-clients \
        libvirt-daemon-system \
        libvirt-daemon-system \
        libvirt-dev \
        qemu-user-static \
        qemu-system \
        ruby-fog-libvirt \
        ruby-libvirt \
        virtinst
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

    # install virter
    unset CONFIRMATION
    read -p "Download latest version of LINBIT/virter from GitHub [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      if [[ -x "$LOCAL_BIN_PATH"/fetch ]] && [[ -n $LINUX ]] && [[ -z $WSL ]] && [[ "$LINUX_ARCH" == "amd64" ]]; then
        ASSETS=(
          "https://github.com/LINBIT/virter|^virter-linux-amd64$|$LOCAL_BIN_PATH/virter|755"
          "https://github.com/LINBIT/vmshed|^vmshed-linux-amd64$|$LOCAL_BIN_PATH/vmshed|755"
        )
        for i in ${ASSETS[@]}; do
          _DownloadViaFetch "$i"
        done
        echo "" >&2
      fi

      unset CONFIRMATION
      read -p "Configure AppArmor for LINBIT/virter [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        $SUDO_CMD tee -a /etc/apparmor.d/local/abstractions/libvirt-qemu > /dev/null <<'EOT'
/var/lib/libvirt/images/* rwk,
# required for QEMU accessing UEFI nvram variables
/usr/share/OVMF/* rk,
owner /var/lib/libvirt/qemu/nvram/*_VARS.fd rwk,
owner /var/lib/libvirt/qemu/nvram/*_VARS.ms.fd rwk,
EOT
        $SUDO_CMD systemctl daemon-reload && \
          $SUDO_CMD systemctl restart apparmor.service
          $SUDO_CMD systemctl restart libvirtd.service
      fi
    fi

    # install Vagrant
    unset CONFIRMATION
    read -p "Attempt to download and install latest version of Vagrant from releases.hashicorp.com [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      curl -o /tmp/vagrant.deb "$(curl -fsL "https://releases.hashicorp.com$(curl -fsL "https://releases.hashicorp.com/vagrant" | grep 'href="/vagrant/' | head -n 1 | grep -o '".*"' | tr -d '"' )" | grep "amd64\.deb" | head -n 1 | grep -o 'href=".*"' | sed 's/href=//' | tr -d '"')"
      $SUDO_CMD dpkg -i /tmp/vagrant.deb
      rm -f /tmp/vagrant.deb

    else
      unset CONFIRMATION
      read -p "Install vagrant via apt-get instead [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y vagrant

      elif command -v ${CONTAINER_ENGINE} >/dev/null 2>&1 ; then
        unset CONFIRMATION
        read -p "Pull ghcr.io/mmguero-dev/vagrant-libvirt:latest instead [Y/n]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-Y}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          ${CONTAINER_ENGINE} pull ghcr.io/mmguero-dev/vagrant-libvirt:latest
        fi
      fi
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
    read -p "Install common vagrant boxes (linux) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      VAGRANT_BOXES=(
        bento/amazonlinux-2
        bento/debian-12
        bento/ubuntu-23.04
        clink15/pxe
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
      brew install direnv
      brew install dos2unix
      brew install eza

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

      brew install detox
      brew install fx
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

  elif [[ -n $MSYSTEM ]]; then

    unset CONFIRMATION
    read -p "Install common packages [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      if [[ -n $HAS_SCOOP ]]; then
        scoop bucket add extras
        SCOOP_PACKAGE_LIST=(
          main/dark
          main/innounp
          main/7zip
          main/bat
          main/cloc
          main/difftastic
          main/diffutils
          main/direnv
          main/dos2unix
          main/eza
          main/fd
          main/file
          main/findutils
          main/fx
          main/gnupg
          main/gron
          main/jdupes
          main/patch
          main/peco
          main/python
          main/ripgrep
          main/sops
          main/sqlite
          main/starship
          main/sudo
          main/time
          main/unrar
          main/vim
          main/watchexec
          main/yq
          main/zip
          extras/age
          extras/viddy
        )
        for i in ${SCOOP_PACKAGE_LIST[@]}; do
          scoop install "$i"
        done

      else
        PACMAN_PACKAGE_LIST=(
          ${MINGW_PACKAGE_PREFIX}-bat
          ${MINGW_PACKAGE_PREFIX}-ripgrep
          cloc
          diffutils
          dos2unix
          file
          findutils
          gnupg
          p7zip
          patch
          patchutils
          time
          unrar
          vim
          zip
        )
        for i in ${PACMAN_PACKAGE_LIST[@]}; do
          pacman --noconfirm -Sy "$i"
        done
      fi
    fi

  elif [[ -n $LINUX ]]; then
    unset CONFIRMATION
    read -p "Install common packages [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      _AptUpdate
      DEBIAN_PACKAGE_LIST=(
        apt-file
        apt-listchanges
        apt-show-versions
        apt-transport-https
        apt-utils
        autoconf
        automake
        bash
        bash-completion
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
        detox
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
        inotify-tools
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
        lz4
        make
        moreutils
        musl
        musl-tools
        ncdu
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
        vim-tiny
        zip
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
      curl -L -o "/tmp/veracrypt-console-Debian-11.deb" "$(curl -sSL https://www.veracrypt.fr/en/Downloads.html | grep -Pio "https://.+?veracrypt-console.+?Debian-11-${LINUX_ARCH}.deb" | sed "s/&#43;/+/" | head -n 1)"
      $SUDO_CMD dpkg -i "/tmp/veracrypt-console-Debian-11.deb"
      rm -f "/tmp/veracrypt-console-Debian-11.deb"

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
      brew install --cask barrier
      brew install --cask diskwave
      brew install --cask firefox
      brew install --cask iterm2
      brew install --cask keepassxc
      brew install --cask libreoffice
      brew install --cask osxfuse
      brew install --cask sublime-text
      brew install --cask veracrypt
      brew install --cask wireshark
    fi

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then

    unset CONFIRMATION
    read -p "Install common packages (GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add extras
      SCOOP_PACKAGE_LIST=(
        main/msys2
        extras/bulk-crap-uninstaller
        extras/cpu-z
        extras/meld
        extras/sublime-text
        extras/sumatrapdf
        extras/sysinternals
        extras/vcredist2022
        extras/win32-disk-imager
        extras/windows-terminal
      )
      for i in ${SCOOP_PACKAGE_LIST[@]}; do
        scoop install "$i"
      done
    fi

    unset CONFIRMATION
    read -p "Install common packages (GUI, office) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add extras
      SCOOP_PACKAGE_LIST=(
        extras/libreoffice
      )
      for i in ${SCOOP_PACKAGE_LIST[@]}; do
        scoop install "$i"
      done
    fi

  elif [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    unset CONFIRMATION
    read -p "Install common packages (GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      _AptUpdate
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
    fi

  fi # Mac vs Linux

  if python3 -m pip -V >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "Install common pip packages (GUI) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && \
      python3 -m pip install -U \
        customtkinter && \
        [[ -n $LINUX ]] && \
          DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
            tk-dev
  fi
}

################################################################################
function InstallCommonPackagesMedia {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    unset CONFIRMATION
    read -p "Install common packages (media) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      _AptUpdate
      DEBIAN_PACKAGE_LIST=(
        audacious
        audacity
        ffmpeg
        kazam
        imagemagick
        mpv
        pavucontrol
        pqiv
        recordmydesktop
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done

      unset CONFIRMATION
      read -p "Install common packages (media/GIMP) [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        _AptUpdate
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

  elif [[ -n $MSYSTEM ]]; then

    unset CONFIRMATION
    read -p "Install common packages (media) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      if [[ -n $HAS_SCOOP ]]; then
        scoop bucket add extras
        SCOOP_PACKAGE_LIST=(
          main/ffmpeg
          main/imagemagick
          extras/audacious
          extras/audacity
          extras/irfanview
          extras/mkvtoolnix
          extras/mpv
          extras/vlc
        )
        for i in ${SCOOP_PACKAGE_LIST[@]}; do
          scoop install "$i"
        done

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

      else
        PACMAN_PACKAGE_LIST=(
          ${MINGW_PACKAGE_PREFIX}-ffmpeg
          ${MINGW_PACKAGE_PREFIX}-imagemagick

        )
        for i in ${PACMAN_PACKAGE_LIST[@]}; do
          pacman --noconfirm -Sy "$i"
        done
      fi
    fi
  fi # Linux vs. MSYS

  if python3 -m pip -V >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "Install common pip packages (media) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && \
      python3 -m pip install -U \
        cleanvid \
        monkeyplug \
        montag-cleaner \
        Pillow \
        yt-dlp && \
        [[ -n $LINUX ]] && \
          DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y \
            libfreetype6-dev \
            libharfbuzz-dev \
            libjpeg-dev \
            liblcms2-dev \
            libopenjp2-7-dev \
            libtiff5-dev \
            libwebp-dev \
            tk-dev
  fi
}

################################################################################
function InstallCommonPackagesNetworking {
  if [[ -n $LINUX ]]; then

    unset CONFIRMATION
    read -p "Install common packages (networking) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      _AptUpdate
      DEBIAN_PACKAGE_LIST=(
        apache2-utils
        autossh
        bridge-utils
        cifs-utils
        cryptcat
        curl
        dnsmasq-utils
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

  elif [[ -n $MSYSTEM ]]; then
    unset CONFIRMATION
    read -p "Install common packages (networking) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      if [[ -n $HAS_SCOOP ]]; then
        scoop bucket add extras
        scoop bucket add smallstep https://github.com/smallstep/scoop-bucket.git

        SCOOP_PACKAGE_LIST=(
          main/autossh
          main/boringproxy
          main/croc
          main/cwrsync
          main/ffsend
          main/ghorg
          main/netcat
          main/nmap
          main/rclone
          main/wget
          main/xh
          extras/stunnel
          mmguero/fluent-bit
          smallstep/step
        )
        for i in ${SCOOP_PACKAGE_LIST[@]}; do
          scoop install "$i"
        done
        echo '$ step ca bootstrap --ca-url https://step.example.org:9000 --fingerprint xxxxxxx --install' >&2
        echo '$ cp ~/.step/certs/root_ca.crt /etc/pki/ca-trust/source/anchors/example.crt' >&2
        echo '$ update-ca-trust' >&2
        echo 'for firefox: set security.enterprise_roots.enabled to true' >&2

      else
        PACMAN_PACKAGE_LIST=(
          openbsd-netcat
          rsync
          wget
        )
        for i in ${PACMAN_PACKAGE_LIST[@]}; do
          pacman --noconfirm -Sy "$i"
        done
      fi
    fi

  fi # Linux vs. MSYS

  if python3 -m pip -V >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "Install common pip packages (network) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && \
      python3 -m pip install -U \
        beautifulsoup4 \
        netmiko \
        pyshark \
        requests-html \
        requests\[security\] \
        scapy \
        urllib3
  fi
}

################################################################################
function InstallLatestFirefoxLinuxAmd64 {
  if [[ -n $LINUX ]] && [[ -z $WSL ]] && [[ "$LINUX_ARCH" == "amd64" ]]; then

    unset CONFIRMATION
    read -p "Install firefox under \"$LOCAL_DATA_PATH\" [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      FIREFOX_DIR="$LOCAL_DATA_PATH"/firefox
      FIREFOX_SUDO_CMD=
      FIREFOX_LINK_DIR=$LOCAL_BIN_PATH
      FIREFOX_DESKTOP="$LOCAL_DATA_PATH"/applications/firefox.desktop
    else
      FIREFOX_DIR=/opt/firefox
      FIREFOX_SUDO_CMD=$SUDO_CMD
      FIREFOX_LINK_DIR=/usr/local/bin
      FIREFOX_DESKTOP=/usr/share/applications/firefox.desktop
    fi
    curl -o /tmp/firefox.tar.bz2 -L "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US"
    if [[ $(file -b --mime-type /tmp/firefox.tar.bz2) = 'application/x-bzip2' ]]; then
      $FIREFOX_SUDO_CMD mkdir -p "$(dirname "$FIREFOX_DIR")"
      $FIREFOX_SUDO_CMD rm -rvf "$FIREFOX_DIR"
      $FIREFOX_SUDO_CMD tar -xvf /tmp/firefox.tar.bz2 -C "$(dirname "$FIREFOX_DIR")"/
      rm -vf /tmp/firefox.tar.bz2
      if [[ -f "$FIREFOX_DIR"/firefox ]]; then
        $FIREFOX_SUDO_CMD rm -vf "$FIREFOX_LINK_DIR"/firefox
        $FIREFOX_SUDO_CMD ln -rs "$FIREFOX_DIR"/firefox "$FIREFOX_LINK_DIR"/firefox
        $FIREFOX_SUDO_CMD tee "$FIREFOX_DESKTOP" > /dev/null <<EOT
[Desktop Entry]
Name=Firefox
Comment=Web Browser
GenericName=Web Browser
X-GNOME-FullName=Firefox Web Browser
Exec=$FIREFOX_DIR/firefox %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=$FIREFOX_DIR/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=Firefox
StartupNotify=true
EOT
      fi
    fi # /tmp/firefox.tar.bz2 check
  fi # Linux
}


################################################################################
function InstallCommonPackagesNetworkingGUI {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then

    unset CONFIRMATION
    read -p "Install common packages (networking, GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      _AptUpdate
      DEBIAN_PACKAGE_LIST=(
        wireshark
        x2goclient
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done

      DEBIAN_PACKAGE_LIST=(
        barrier
      )
      for i in ${DEBIAN_PACKAGE_LIST[@]}; do
        DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y $LINUX_BACKPORTS_REPO_APT_FLAG "$i" 2>&1 | grep -Piv "(Reading package lists|Building dependency tree|Reading state information|already the newest|\d+ upgraded, \d+ newly installed, \d+ to remove and \d+ not upgraded)"
      done
    fi

    if [[ "$LINUX_ARCH" == "amd64" ]]; then
      unset CONFIRMATION
      read -p "Install latest Firefox [y/N]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-N}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        InstallLatestFirefoxLinuxAmd64
      fi
    fi

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Install common packages (networking, GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add extras
      SCOOP_PACKAGE_LIST=(
        extras/filezilla
        extras/putty
        extras/winscp
        mmguero/x2goclient
      )
      for i in ${SCOOP_PACKAGE_LIST[@]}; do
        scoop install "$i"
      done

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
        scoop install extras/barrier
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
      _AptUpdate
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

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Install common packages (forensics/security) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      SCOOP_PACKAGE_LIST=(
        main/adb
        main/exiftool
        extras/testdisk
      )
      for i in ${SCOOP_PACKAGE_LIST[@]}; do
        scoop install "$i"
      done
    fi

  fi # Linux vs. MSYS

  if python3 -m pip -V >/dev/null 2>&1 ; then
    unset CONFIRMATION
    read -p "Install common pip packages (forensics/security) [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    [[ $CONFIRMATION =~ ^[Yy] ]] && \
      python3 -m pip install -U \
        chepy[extras] \
        cryptography && \
      [[ ! -d "$LOCAL_CONFIG_PATH"/chepy_plugins ]] && \
        _GitClone https://github.com/securisec/chepy_plugins "$LOCAL_CONFIG_PATH"/chepy_plugins
  fi
}


################################################################################
function InstallCommonPackagesForensicsGUI {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then
    unset CONFIRMATION
    read -p "Install common packages (forensics/security, GUI) [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      _AptUpdate
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

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then
    # nothing for now
    true

  fi # Linux vs. MSYS
}

################################################################################
function InstallCockpit {
  if [[ -n $LINUX ]] && [[ -z $WSL ]]; then
    unset CONFIRMATION
    read -p "Install cockpit [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then

      _AptUpdate
      DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install \
        -y --no-install-recommends $LINUX_BACKPORTS_REPO_APT_FLAG \
          cockpit \
          cockpit-bridge \
          cockpit-networkmanager \
          cockpit-packagekit \
          cockpit-storaged \
          cockpit-system \
          cockpit-ws \
          libblockdev-mdraid2 \
          libbytesize-common \
          libbytesize1 \
          libpwquality-tools \
          sssd-dbus

      for SYSTEMD_SERVICE_PATH in /usr/lib/systemd /lib/systemd; do
        [[ -f "$SYSTEMD_SERVICE_PATH"/system/cockpit.service ]] && \
          ! grep -q '^\[Install\]' "$SYSTEMD_SERVICE_PATH"/system/cockpit.service && \
          echo -e "\n[Install]\nWantedBy=multi-user.target" | $SUDO_CMD tee -a "$SYSTEMD_SERVICE_PATH"/system/cockpit.service
      done

      $SUDO_CMD systemctl daemon-reload && \
        $SUDO_CMD systemctl start cockpit && \
        $SUDO_CMD systemctl enable cockpit
    fi
  fi # Linux
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

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Create missing common local config in home [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      touch "$HOME"/.hushlogin

      mkdir -p "$HOME/tmp" \
               "$HOME/media" \
               "$LOCAL_BIN_PATH"

      if command -v cygpath >/dev/null 2>&1 && [[ -n $USERPROFILE ]]; then
        WIN_HOME="$(cygpath -u "$USERPROFILE")"

        [[ -d "$WIN_HOME"/Downloads ]] && \
          ln -s "$WIN_HOME"/Downloads "$HOME"/download
        [[ -d "$WIN_HOME"/Documents ]] && \
          ln -s "$WIN_HOME"/Documents "$HOME"/Documents
        [[ -d "$WIN_HOME"/Desktop ]] && \
          ln -s "$WIN_HOME"/Desktop "$HOME"/Desktop
        [[ -d "$WIN_HOME"/Pictures ]] && \
          ln -s "$WIN_HOME"/Pictures "$HOME"/media/images
        [[ -d "$WIN_HOME"/Music ]] && \
          ln -s "$WIN_HOME"/Music "$HOME"/media/music
        [[ -d "$WIN_HOME"/Videos ]] && \
          ln -s "$WIN_HOME"/Videos "$HOME"/media/video
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
function InstallUserLocalThemes {
  if [[ -n $LINUX ]] && [[ -z $WSL ]] && [[ -x "$LOCAL_BIN_PATH"/fetch ]]; then
      unset CONFIRMATION
      read -p "Install user-local themes [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        [[ -z "$GITHUB_OAUTH_TOKEN" ]] && [[ -n "$GITHUB_TOKEN" ]] && export GITHUB_OAUTH_TOKEN="$GITHUB_TOKEN"
        mkdir -p "$LOCAL_DATA_PATH"/icons "$HOME"/.themes

        pushd "$HOME"/.themes >/dev/null 2>&1
        rm -rf ./Nordic-darker ./Nordic-Polar
        "$LOCAL_BIN_PATH"/fetch --log-level warn \
          --repo="https://github.com/EliverLara/Nordic" \
          --tag=">=0.0.0" \
          --release-asset="Nordic(-darker|-Polar)?\.tar\.xz" .
        for FILE in *.tar.xz; do
          tar xf "$FILE"
          rm -f "$FILE"
        done
        popd >/dev/null 2>&1

        pushd "$LOCAL_DATA_PATH"/icons >/dev/null 2>&1
        rm -rf ./Zafiro* Nordzy*
        "$LOCAL_BIN_PATH"/fetch --log-level warn \
          --repo="https://github.com/zayronxio/Zafiro-icons" \
          --tag=">=0.0.0" \
          --release-asset="Zafiro-Icons-(Dark|Light)\.tar\.xz" .
        "$LOCAL_BIN_PATH"/fetch --log-level warn \
          --repo="https://github.com/alvatip/Nordzy-icon" \
          --tag=">=0.0.0" \
          --release-asset="Nordzy(-dark)?\.tar\.gz" .
        for FILE in Zafiro*.tar.*z Nordzy*.tar.*z; do
          tar xf "$FILE"
          rm -f "$FILE"
        done
        for FILE in Zafiro* Nordzy*; do
          gtk-update-icon-cache ./"$FILE" >/dev/null 2>&1
        done
        popd >/dev/null 2>&1
      fi
  fi
}

################################################################################
function InstallUserLocalFonts {
  if [[ -n $MACOS ]]; then
    unset CONFIRMATION
    read -p "Install user-local fonts [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      brew install --cask font-hack-nerd-font
    fi

  elif [[ -n $LINUX ]] && [[ -z $WSL ]]; then
    unset CONFIRMATION
    read -p "Install user-local fonts [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      mkdir -p "$LOCAL_DATA_PATH"/fonts "$LOCAL_CONFIG_PATH"/fontconfig/conf.d

      pushd "$LOCAL_DATA_PATH"/fonts >/dev/null 2>&1
      for NERDFONT in DejaVuSansMono FiraCode FiraMono Hack Incosolata LiberationMono SourceCodePro Ubuntu UbuntuMono; do
        curl -L -o ./$NERDFONT.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$NERDFONT.zip"
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

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then
    unset CONFIRMATION
    read -p "Install user-local fonts [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      scoop bucket add nerd-fonts
      scoop install nerd-fonts/Hack-NF nerd-fonts/Hack-NF-Mono
    fi

  fi # Linux vs. MSYS
}

################################################################################
function InstallUserLocalBinaries {
  if [[ -n $LINUX ]]; then
    unset CONFIRMATION
    read -p "Install user-local binaries [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      mkdir -p "$LOCAL_BIN_PATH" "$LOCAL_DATA_PATH"/bash-completion/completions

      unset CONFIRMATION
      read -p "Download all user-local binaries [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        BINARY_UPDATE_ALL=true
      else
        BINARY_UPDATE_ALL=false
      fi

      # pcloud (and other one-offs)
      if [[ "$LINUX_ARCH" == "amd64" ]] && [[ -z $WSL ]]; then
        [[ "$BINARY_UPDATE_ALL" == "true" ]] && BINARY_UPDATE=true || BINARY_UPDATE=false
        if [[ "$BINARY_UPDATE" == "false" ]]; then
          unset CONFIRMATION
          read -p "Download pcloud [y/N]? " CONFIRMATION
          CONFIRMATION=${CONFIRMATION:-N}
          [[ $CONFIRMATION =~ ^[Yy] ]] && BINARY_UPDATE=true
        fi
        if [[ "$BINARY_UPDATE" == "true" ]]; then
          PCLOUD_URL="https://filedn.com/lqGgqyaOApSjKzN216iPGQf/Software/Linux/pcloud"
          curl -fsSL "$PCLOUD_URL" > "$LOCAL_BIN_PATH"/pcloud.new
          chmod 755 "$LOCAL_BIN_PATH"/pcloud.new
          [[ -f "$LOCAL_BIN_PATH"/pcloud ]] && mv "$LOCAL_BIN_PATH"/pcloud "$LOCAL_BIN_PATH"/pcloud.old
          mv "$LOCAL_BIN_PATH"/pcloud.new "$LOCAL_BIN_PATH"/pcloud && rm -f "$LOCAL_BIN_PATH"/pcloud.old
        fi
      fi

      # github releases via fetch
      if [[ -x "$LOCAL_BIN_PATH"/fetch ]]; then
        if [[ "$LINUX_ARCH" =~ ^arm ]]; then
          if [[ "$LINUX_CPU" == "aarch64" ]]; then
            ASSETS=(
              "https://github.com/antonmedv/fx|^fx_linux_arm64$|$LOCAL_BIN_PATH/fx|755"
              "https://github.com/aptible/supercronic|^supercronic-linux-arm64$|$LOCAL_BIN_PATH/supercronic|755"
              "https://github.com/boringproxy/boringproxy|^boringproxy-linux-arm64$|$LOCAL_BIN_PATH/boringproxy|755"
              "https://github.com/BurntSushi/ripgrep|^ripgrep-.+-arm-unknown-linux-gnueabihf\.tar\.gz$|/tmp/ripgrep.tar.gz"
              "https://github.com/darkhz/bluetuith|^bluetuith_.*_Linux_arm64.tar.gz$|/tmp/bluetuith.tar.gz"
              "https://github.com/darkhz/rclone-tui|^rclone-tui_.+_Linux_arm64\.tar\.gz$|/tmp/rclone-tui.tar.gz"
              "https://github.com/docker/docker-credential-helpers|^docker-credential-pass-v.+\.linux-arm64$|$LOCAL_BIN_PATH/docker-credential-pass|755"
              "https://github.com/docker/docker-credential-helpers|^docker-credential-secretservice-v.+\.linux-arm64$|$LOCAL_BIN_PATH/docker-credential-secretservice|755"
              "https://github.com/eza-community/eza|^eza_aarch64-unknown-linux-gnu\.tar\.gz$|/tmp/eza.tar.gz"
              "https://github.com/FiloSottile/age|^age-v.+-linux-arm64\.tar\.gz$|/tmp/age.tar.gz"
              "https://github.com/gabrie30/ghorg|^ghorg_.+_Linux_arm64\.tar\.gz$|/tmp/ghorg.tar.gz"
              "https://github.com/gcla/termshark|^termshark_.+_linux_arm64\.tar\.gz$|/tmp/termshark.tar.gz"
              "https://github.com/mikefarah/yq|^yq_linux_arm64$|$LOCAL_BIN_PATH/yq|755"
              "https://github.com/neilotoole/sq|^sq-.+arm64-arm64\.tar\.gz$|/tmp/sq.tar.gz"
              "https://github.com/nektos/act|^act_Linux_arm64\.tar\.gz$|/tmp/act.tar.gz"
              "https://github.com/peco/peco|^peco_linux_arm64\.tar\.gz$|/tmp/peco.tar.gz"
              "https://github.com/projectdiscovery/httpx|^httpx_.+_linux_arm64\.zip$|/tmp/httpx.zip"
              "https://github.com/rclone/rclone|^rclone-v.+-linux-arm64\.zip$|/tmp/rclone.zip"
              "https://github.com/sachaos/viddy|^viddy_Linux_arm64\.tar\.gz$|/tmp/viddy.tar.gz"
              "https://github.com/schollz/croc|^croc_.+_Linux-ARM64\.tar\.gz$|/tmp/croc.tar.gz"
              "https://github.com/schollz/hostyoself|^hostyoself_.+_Linux-ARM64\.tar\.gz$|/tmp/hostyoself.tar.gz"
              "https://github.com/sharkdp/bat|^bat-v.+-aarch64-unknown-linux-gnu\.tar\.gz$|/tmp/bat.tar.gz"
              "https://github.com/sharkdp/fd|^fd-v.+-aarch64-unknown-linux-gnu\.tar\.gz$|/tmp/fd.tar.gz"
              "https://github.com/smallstep/cli|^step_linux_.+_arm64\.tar\.gz$|/tmp/step.tar.gz"
              "https://github.com/starship/starship|^starship-aarch64-unknown-linux-musl\.tar\.gz$|/tmp/starship.tar.gz"
              "https://github.com/stern/stern|^stern_.+_linux_arm64\.tar\.gz$|/tmp/stern.tar.gz"
              "https://github.com/tomnomnom/gron|^gron-linux-arm64-.+\.tgz$|/tmp/gron.tgz"
              "https://github.com/wader/fq|^fq_.+_linux_arm64\.tar\.gz$|/tmp/fq.tar.gz"
              "https://github.com/watchexec/watchexec|^watchexec-.+-aarch64-unknown-linux-musl\.tar\.xz$|/tmp/watchexec.tar.xz"
            )
          elif [[ "$LINUX_CPU" == "armv6l" ]]; then
            ASSETS=(
              "https://github.com/aptible/supercronic|^supercronic-linux-arm$|$LOCAL_BIN_PATH/supercronic|755"
              "https://github.com/boringproxy/boringproxy|^boringproxy-linux-arm$|$LOCAL_BIN_PATH/boringproxy|755"
              "https://github.com/BurntSushi/ripgrep|^ripgrep-.+-arm-unknown-linux-gnueabihf\.tar\.gz$|/tmp/ripgrep.tar.gz"
              "https://github.com/darkhz/bluetuith|^bluetuith_.*_Linux_armv6.tar.gz$|/tmp/bluetuith.tar.gz"
              "https://github.com/darkhz/rclone-tui|^rclone-tui_.+_Linux_armv6\.tar\.gz$|/tmp/rclone-tui.tar.gz"
              "https://github.com/docker/docker-credential-helpers|^docker-credential-pass-v.+\.linux-armv6$|$LOCAL_BIN_PATH/docker-credential-pass|755"
              "https://github.com/docker/docker-credential-helpers|^docker-credential-secretservice-v.+\.linux-armv6$|$LOCAL_BIN_PATH/docker-credential-secretservice|755"
              "https://github.com/eza-community/eza|^eza_arm-unknown-linux-gnueabihf\.tar\.gz$|/tmp/eza.tar.gz"
              "https://github.com/FiloSottile/age|^age-v.+-linux-arm\.tar\.gz$|/tmp/age.tar.gz"
              "https://github.com/gcla/termshark|^termshark_.+_linux_armv6\.tar\.gz$|/tmp/termshark.tar.gz"
              "https://github.com/mikefarah/yq|^yq_linux_arm$|$LOCAL_BIN_PATH/yq|755"
              "https://github.com/nektos/act|^act_Linux_armv6\.tar\.gz$|/tmp/act.tar.gz"
              "https://github.com/peco/peco|^peco_linux_arm\.tar\.gz$|/tmp/peco.tar.gz"
              "https://github.com/projectdiscovery/httpx|^httpx_.+_linux_armv6\.zip$|/tmp/httpx.zip"
              "https://github.com/rclone/rclone|^rclone-v.+-linux-arm\.zip$|/tmp/rclone.zip"
              "https://github.com/sachaos/viddy|^viddy_Linux_armv6\.tar\.gz$|/tmp/viddy.tar.gz"
              "https://github.com/schollz/croc|^croc_.+_Linux-ARM\.tar\.gz$|/tmp/croc.tar.gz"
              "https://github.com/schollz/hostyoself|^hostyoself_.+_Linux-ARM\.tar\.gz$|/tmp/hostyoself.tar.gz"
              "https://github.com/sharkdp/bat|^bat-v.+-arm-unknown-linux-musleabihf\.tar\.gz$|/tmp/bat.tar.gz"
              "https://github.com/sharkdp/fd|^fd-v.+-arm-unknown-linux-musleabihf\.tar\.gz$|/tmp/fd.tar.gz"
              "https://github.com/smallstep/cli|^step_linux_.+_armv6\.tar\.gz$|/tmp/step.tar.gz"
              "https://github.com/starship/starship|^starship-arm-unknown-linux-musleabihf\.tar\.gz$|/tmp/starship.tar.gz"
              "https://github.com/watchexec/watchexec|^watchexec-.+-armv7-unknown-linux-gnueabihf\.tar\.xz$|/tmp/watchexec.tar.xz"
            )
          else
            ASSETS=(
              "https://github.com/aptible/supercronic|^supercronic-linux-arm$|$LOCAL_BIN_PATH/supercronic|755"
              "https://github.com/boringproxy/boringproxy|^boringproxy-linux-arm$|$LOCAL_BIN_PATH/boringproxy|755"
              "https://github.com/BurntSushi/ripgrep|^ripgrep-.+-arm-unknown-linux-gnueabihf\.tar\.gz$|/tmp/ripgrep.tar.gz"
              "https://github.com/darkhz/bluetuith|^bluetuith_.*_Linux_armv7.tar.gz$|/tmp/bluetuith.tar.gz"
              "https://github.com/darkhz/rclone-tui|^rclone-tui_.+_Linux_armv7\.tar\.gz$|/tmp/rclone-tui.tar.gz"
              "https://github.com/docker/docker-credential-helpers|^docker-credential-pass-v.+\.linux-armv7$|$LOCAL_BIN_PATH/docker-credential-pass|755"
              "https://github.com/docker/docker-credential-helpers|^docker-credential-secretservice-v.+\.linux-armv7$|$LOCAL_BIN_PATH/docker-credential-secretservice|755"
              "https://github.com/eza-community/eza|^eza_arm-unknown-linux-gnueabihf\.tar\.gz$|/tmp/eza.tar.gz"
              "https://github.com/FiloSottile/age|^age-v.+-linux-arm\.tar\.gz$|/tmp/age.tar.gz"
              "https://github.com/gcla/termshark|^termshark_.+_linux_armv6\.tar\.gz$|/tmp/termshark.tar.gz"
              "https://github.com/mikefarah/yq|^yq_linux_arm$|$LOCAL_BIN_PATH/yq|755"
              "https://github.com/nektos/act|^act_Linux_armv7\.tar\.gz$|/tmp/act.tar.gz"
              "https://github.com/peco/peco|^peco_linux_arm\.tar\.gz$|/tmp/peco.tar.gz"
              "https://github.com/projectdiscovery/httpx|^httpx_.+_linux_armv6\.zip$|/tmp/httpx.zip"
              "https://github.com/rclone/rclone|^rclone-v.+-linux-arm-v7\.zip$|/tmp/rclone.zip"
              "https://github.com/sachaos/viddy|^viddy_Linux_armv6\.tar\.gz$|/tmp/viddy.tar.gz"
              "https://github.com/schollz/croc|^croc_.+_Linux-ARM\.tar\.gz$|/tmp/croc.tar.gz"
              "https://github.com/schollz/hostyoself|^hostyoself_.+_Linux-ARM\.tar\.gz$|/tmp/hostyoself.tar.gz"
              "https://github.com/sharkdp/bat|^bat-v.+-arm-unknown-linux-musleabihf\.tar\.gz$|/tmp/bat.tar.gz"
              "https://github.com/sharkdp/fd|^fd-v.+-arm-unknown-linux-musleabihf\.tar\.gz$|/tmp/fd.tar.gz"
              "https://github.com/smallstep/cli|^step_linux_.+_armv7\.tar\.gz$|/tmp/step.tar.gz"
              "https://github.com/starship/starship|^starship-arm-unknown-linux-musleabihf\.tar\.gz$|/tmp/starship.tar.gz"
              "https://github.com/stern/stern|^stern_.+_linux_arm\.tar\.gz$|/tmp/stern.tar.gz"
              "https://github.com/watchexec/watchexec|^watchexec-.+-armv7-unknown-linux-gnueabihf\.tar\.xz$|/tmp/watchexec.tar.xz"
            )
          fi
        else
          ASSETS=(
            "https://github.com/alphasoc/flightsim|^flightsim_.+_linux_amd64\.tar\.gz$|/tmp/flightsim.tar.gz"
            "https://github.com/antonmedv/fx|^fx_linux_amd64$|$LOCAL_BIN_PATH/fx|755"
            "https://github.com/aptible/supercronic|^supercronic-linux-amd64$|$LOCAL_BIN_PATH/supercronic|755"
            "https://github.com/boringproxy/boringproxy|^boringproxy-linux-x86_64$|$LOCAL_BIN_PATH/boringproxy|755"
            "https://github.com/BurntSushi/ripgrep|^ripgrep-.+-x86_64-unknown-linux-musl\.tar\.gz$|/tmp/ripgrep.tar.gz"
            "https://github.com/darkhz/bluetuith|^bluetuith_.*_Linux_x86_64.tar.gz$|/tmp/bluetuith.tar.gz"
            "https://github.com/darkhz/rclone-tui|^rclone-tui_.+_Linux_x86_64\.tar\.gz$|/tmp/rclone-tui.tar.gz"
            "https://github.com/docker/docker-credential-helpers|^docker-credential-pass-v.+\.linux-amd64$|$LOCAL_BIN_PATH/docker-credential-pass|755"
            "https://github.com/docker/docker-credential-helpers|^docker-credential-secretservice-v.+\.linux-amd64$|$LOCAL_BIN_PATH/docker-credential-secretservice|755"
            "https://github.com/eza-community/eza|^eza_x86_64-unknown-linux-musl\.tar\.gz$|/tmp/eza.tar.gz"
            "https://github.com/FiloSottile/age|^age-v.+-linux-amd64\.tar\.gz$|/tmp/age.tar.gz"
            "https://github.com/gabrie30/ghorg|^ghorg_.+_Linux_x86_64\.tar\.gz$|/tmp/ghorg.tar.gz"
            "https://github.com/gcla/termshark|^termshark_.+_linux_x64\.tar\.gz$|/tmp/termshark.tar.gz"
            "https://github.com/jez/as-tree|^as-tree-.+-linux\.zip$|/tmp/as-tree.zip"
            "https://github.com/mikefarah/yq|^yq_linux_amd64$|$LOCAL_BIN_PATH/yq|755"
            "https://github.com/neilotoole/sq|^sq-.+amd64-amd64\.tar\.gz$|/tmp/sq.tar.gz"
            "https://github.com/nektos/act|^act_Linux_x86_64\.tar\.gz$|/tmp/act.tar.gz"
            "https://github.com/peco/peco|^peco_linux_amd64\.tar\.gz$|/tmp/peco.tar.gz"
            "https://github.com/projectdiscovery/httpx|^httpx_.+_linux_amd64\.zip$|/tmp/httpx.zip"
            "https://github.com/rclone/rclone|^rclone-v.+-linux-amd64\.zip$|/tmp/rclone.zip"
            "https://github.com/sachaos/viddy|^viddy_Linux_x86_64\.tar\.gz$|/tmp/viddy.tar.gz"
            "https://github.com/schollz/croc|^croc_.+_Linux-64bit\.tar\.gz$|/tmp/croc.tar.gz"
            "https://github.com/schollz/hostyoself|^hostyoself_.+_Linux-64bit\.tar\.gz$|/tmp/hostyoself.tar.gz"
            "https://github.com/sharkdp/bat|^bat-v.+-x86_64-unknown-linux-gnu\.tar\.gz$|/tmp/bat.tar.gz"
            "https://github.com/sharkdp/fd|^fd-v.+-x86_64-unknown-linux-gnu\.tar\.gz$|/tmp/fd.tar.gz"
            "https://github.com/smallstep/cli|^step_linux_.+_amd64\.tar\.gz$|/tmp/step.tar.gz"
            "https://github.com/starship/starship|^starship-x86_64-unknown-linux-gnu\.tar\.gz$|/tmp/starship.tar.gz"
            "https://github.com/stern/stern|^stern_.+_linux_amd64\.tar\.gz$|/tmp/stern.tar.gz"
            "https://github.com/timvisee/ffsend|^ffsend-v.+-linux-x64-static$|$LOCAL_BIN_PATH/ffsend|755"
            "https://github.com/tomnomnom/gron|^gron-linux-amd64-.+\.tgz$|/tmp/gron.tgz"
            "https://github.com/wader/fq|^fq_.+_linux_amd64\.tar\.gz$|/tmp/fq.tar.gz"
            "https://github.com/watchexec/watchexec|^watchexec-.+-x86_64-unknown-linux-musl\.tar\.xz$|/tmp/watchexec.tar.xz"
            "https://github.com/Wilfred/difftastic|^difft-x86_64-unknown-linux-gnu\.tar\.gz$|/tmp/difft.tar.gz"
          )
        fi

        for i in ${ASSETS[@]}; do
          [[ "$BINARY_UPDATE_ALL" == "true" ]] && BINARY_UPDATE=true || BINARY_UPDATE=false
          if [[ "$BINARY_UPDATE" == "false" ]]; then
            unset CONFIRMATION
            read -p "Download $(echo "$i" | cut -d'|' -f1) [y/N]? " CONFIRMATION
            CONFIRMATION=${CONFIRMATION:-N}
            [[ $CONFIRMATION =~ ^[Yy] ]] && BINARY_UPDATE=true
          fi
          [[ "$BINARY_UPDATE" == "true" ]] && _DownloadViaFetch "$i"
        done
        echo "" >&2
      fi
    fi

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then

    unset CONFIRMATION
    read -p "Install user-local binaries [Y/n]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-Y}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      # nothing for now (scoop pretty much did this already)
      ( command -v cygpath >/dev/null 2>&1 && \
          [[ -n $USERPROFILE ]] && \
          [[ -d "$(cygpath -u "$USERPROFILE")"/Downloads ]] && \
          pushd "$(cygpath -u "$USERPROFILE")"/Downloads >/dev/null 2>&1 ) || pushd . >/dev/null 2>&1

        curl -L -J -O "$(curl -sSL https://www.veracrypt.fr/en/Downloads.html | grep -Pio "https://.+?VeraCrypt_Setup_x64.+?\.msi" | sed "s/&#43;/+/" | head -n 1)"
        OPENSHELL_RELEASE="$(_GitLatestRelease Open-Shell/Open-Shell-Menu | sed 's/^v//')"
        curl -L -J -O "https://github.com/Open-Shell/Open-Shell-Menu/releases/download/v${OPENSHELL_RELEASE}/OpenShellSetup_$(echo "${OPENSHELL_RELEASE}" | sed 's/\./_/g').exe"
        curl -L -J -O 'https://filedn.com/lqGgqyaOApSjKzN216iPGQf/Software/Windows/synergy_windows_x64.msi'
        curl -L -J -O 'https://filedn.com/lqGgqyaOApSjKzN216iPGQf/Software/Windows/pCloud_Windows_x64.exe'
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
%netdev ALL=(root) NOPASSWD: /usr/bin/wg-quick
%cryptkeeper ALL=(root) NOPASSWD:/sbin/cryptsetup
%cryptkeeper ALL=(root) NOPASSWD:/usr/bin/veracrypt
%libvirt ALL=(ALL) NOPASSWD: /usr/bin/dhcp_release
EOT
        $SUDO_CMD chmod 440 /etc/sudoers.d/power_groups
      fi # confirmation on group stuff
    fi # ! -f /etc/sudoers.d/power_groups

  elif [[ -n $MSYSTEM ]] && [[ -n $HAS_SCOOP ]]; then
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
      if command -v docker >/dev/null 2>&1 ; then
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
* soft nproc 262144
* hard nproc 524288
* soft core 0
* hard core 0
EOT
      fi # limits.conf confirmation
    fi # limits.conf check

    if [[ -f /etc/default/grub ]] && ! grep -q trust_cpu /etc/default/grub; then
      unset CONFIRMATION
      read -p "Tweak kernel parameters in grub (scheduler, cgroup, etc.) [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        $SUDO_CMD sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\).*/\1"elevator=deadline systemd.unified_cgroup_hierarchy=1 cgroup_enable=memory swapaccount=1 cgroup.memory=nokmem random.trust_cpu=on usbcore.autosuspend=-1"/' /etc/default/grub
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

      [[ -n $MSYSTEM ]] && LNFLAGS='-s' || LNFLAGS='-vrs'

      [[ -r "$GUERO_GITHUB_PATH"/bash/"$SCRIPT_NAME" ]] && rm -vf "$LOCAL_BIN_PATH"/"$SCRIPT_NAME" && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/bash/"$SCRIPT_NAME" "$LOCAL_BIN_PATH"/"$SCRIPT_NAME"

      [[ -r "$GUERO_GITHUB_PATH"/bash/rc ]] && rm -vf "$HOME"/.bashrc && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/bash/rc "$HOME"/.bashrc

      [[ -r "$GUERO_GITHUB_PATH"/bash/aliases ]] && rm -vf "$HOME"/.bash_aliases && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/bash/aliases "$HOME"/.bash_aliases

      [[ -r "$GUERO_GITHUB_PATH"/bash/functions ]] && rm -vf "$HOME"/.bash_functions && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/bash/functions "$HOME"/.bash_functions

      [[ -d "$GUERO_GITHUB_PATH"/bash/rc.d ]] && rm -vf "$HOME"/.bashrc.d && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/bash/rc.d "$HOME"/.bashrc.d

      [[ -d "$GUERO_GITHUB_PATH"/linux/containers ]] && rm -vf "$LOCAL_CONFIG_PATH"/containers && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/linux/containers "$LOCAL_CONFIG_PATH"/containers

      [[ -r "$GUERO_GITHUB_PATH"/starship/starship.toml ]] && rm -vf "$LOCAL_CONFIG_PATH"/starship.toml && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/starship/starship.toml "$LOCAL_CONFIG_PATH"/starship.toml

      [[ -r "$GUERO_GITHUB_PATH"/git/gitconfig ]] && rm -vf "$HOME"/.gitconfig && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/git/gitconfig "$HOME"/.gitconfig

      [[ -r "$GUERO_GITHUB_PATH"/git/gitignore_global ]] && rm -vf "$HOME"/.gitignore_global && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/git/gitignore_global "$HOME"/.gitignore_global

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/tmux/tmux.conf ]] && rm -vf "$HOME"/.tmux.conf && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/linux/tmux/tmux.conf "$HOME"/.tmux.conf

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/pqiv/pqivrc ]] && rm -vf "$LOCAL_CONFIG_PATH"/pqivrc && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/linux/pqiv/pqivrc "$LOCAL_CONFIG_PATH"/pqivrc

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/photorec/photorec.cfg ]] && rm -vf "$HOME"/.photorec.cfg && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/linux/photorec/photorec.cfg "$HOME"/.photorec.cfg

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/xbindkeys/xbindkeysrc ]] && rm -vf "$HOME"/.xbindkeysrc && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/linux/xbindkeys/xbindkeysrc "$HOME"/.xbindkeysrc

      [[ -n $LINUX ]] && [[ -r "$GUERO_GITHUB_PATH"/linux/xxdiff/xxdiffrc ]] && rm -vf "$HOME"/.xxdiffrc && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/linux/xxdiff/xxdiffrc "$HOME"/.xxdiffrc

      # [[ -r "$GUERO_GITHUB_PATH"/gdb/gdbinit ]] && rm -vf "$HOME"/.gdbinit && \
      #   ln $LNFLAGS "$GUERO_GITHUB_PATH"/gdb/gdbinit "$HOME"/.gdbinit

      # [[ -r "$GUERO_GITHUB_PATH"/gdb/cgdbrc ]] && mkdir -p "$HOME"/.cgdb && rm -vf "$HOME"/.cgdb/cgdbrc && \
      #   ln $LNFLAGS "$GUERO_GITHUB_PATH"/gdb/cgdbrc "$HOME"/.cgdb/cgdbrc

      # [[ -r "$GUERO_GITHUB_PATH"/gdb/hexdump.py ]] && mkdir -p "$LOCAL_CONFIG_PATH"/gdb && rm -vf "$LOCAL_CONFIG_PATH"/gdb/hexdump.py && \
      #   ln $LNFLAGS "$GUERO_GITHUB_PATH"/gdb/hexdump.py "$LOCAL_CONFIG_PATH"/gdb/hexdump.py

      # [[ ! -d "$LOCAL_CONFIG_PATH"/gdb/peda ]] && _GitClone https://github.com/longld/peda.git "$LOCAL_CONFIG_PATH"/gdb/peda

      if [[ -n $LINUX ]] && dpkg -s xfce4 >/dev/null 2>&1 && [[ -d "$GUERO_GITHUB_PATH"/linux/xfce-desktop.config ]]; then
        unset CONFIRMATION
        read -p "Setup symlinks for XFCE config [y/N]? " CONFIRMATION
        CONFIRMATION=${CONFIRMATION:-N}
        if [[ $CONFIRMATION =~ ^[Yy] ]]; then
          while IFS= read -d $'\0' -r CONFDIR; do
            DIRNAME="$(basename "$CONFDIR")"
            rm -vf "$LOCAL_CONFIG_PATH"/"$DIRNAME" && ln $LNFLAGS "$CONFDIR" "$LOCAL_CONFIG_PATH"/"$DIRNAME"
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
          rm -vf "$LOCAL_CONFIG_PATH"/sublime-text-3/Packages/User/"$FNAME" && ln $LNFLAGS "$CONFFILE" "$LOCAL_CONFIG_PATH"/sublime-text-3/Packages/User/"$FNAME"
        done < <(find "$GUERO_GITHUB_PATH"/sublime -mindepth 1 -maxdepth 1 -type f -print0)
      fi

      LINKED_SCRIPTS=(
        pem_passwd.sh
        self_signed_key_gen.sh
        store_unique.sh
        window_dimensions.sh
        tx-rx-secure.sh
      )
      for i in ${LINKED_SCRIPTS[@]}; do
        rm -vf "$LOCAL_BIN_PATH"/"$i" && ln $LNFLAGS "$GUERO_GITHUB_PATH"/scripts/"$i" "$LOCAL_BIN_PATH"/
      done

      [[ -r "$GUERO_GITHUB_PATH"/bash/context-color/context-color ]] && rm -vf "$LOCAL_BIN_PATH"/context-color && \
        ln $LNFLAGS "$GUERO_GITHUB_PATH"/bash/context-color/context-color "$LOCAL_BIN_PATH"/context-color

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
      https://raw.githubusercontent.com/mmguero/docker/master/fetch/fetch-docker.sh
      https://raw.githubusercontent.com/mmguero/docker/master/roop/roop-docker.sh
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
  InstallCockpit
  InstallDocker
  InstallPodman
  InstallContainerCompose
  InstallKubernetes
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
  InstallUserLocalThemes
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
