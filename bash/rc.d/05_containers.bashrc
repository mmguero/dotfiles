unset DOCKER_HOST
export WINDOWS_USER=$USER
export CONTAINER_SHARE_HOME=$HOME
[[ -d "$CONTAINER_SHARE_HOME"/tmp ]] && export CONTAINER_SHARE_TMP="-v "$(realpath "$CONTAINER_SHARE_HOME"/tmp)":/host:rw"
[[ -f "$CONTAINER_SHARE_HOME"/.bashrc ]] && export CONTAINER_SHARE_BASH_RC="-v "$(realpath "$CONTAINER_SHARE_HOME"/.bashrc)":/etc/bash.bashrc:ro"
[[ -d "$CONTAINER_SHARE_HOME"/.bashrc.d ]] && export CONTAINER_SHARE_BASH_RC_D="-v "$(realpath "$CONTAINER_SHARE_HOME"/.bashrc.d)":/etc/bashrc.d:ro"
[[ -d "$CONTAINER_SHARE_HOME"/.ssh ]] && export CONTAINER_SHARE_SSH="-v "$(realpath "$CONTAINER_SHARE_HOME"/.ssh)":"$CONTAINER_SHARE_HOME"/.ssh:ro"
[[ -f "$CONTAINER_SHARE_HOME"/.bash_aliases ]] && export CONTAINER_SHARE_BASH_ALIASES="-v "$(realpath "$CONTAINER_SHARE_HOME"/.bash_aliases)":/etc/bash.bash_aliases:ro"
[[ -f "$CONTAINER_SHARE_HOME"/.bash_functions ]] && export CONTAINER_SHARE_BASH_FUNCTIONS="-v "$(realpath "$CONTAINER_SHARE_HOME"/.bash_functions)":/etc/bash.bash_functions:ro"
[[ -f "$CONTAINER_SHARE_HOME"/.gitconfig ]] && export CONTAINER_SHARE_GIT_CONFIG="-v "$(realpath "$CONTAINER_SHARE_HOME"/.gitconfig)":/etc/gitconfig:ro"
[[ -f "$CONTAINER_SHARE_HOME"/.config/starship.toml ]] && export CONTAINER_SHARE_STARSHIP_CONFIG="-v "$(realpath "$CONTAINER_SHARE_HOME"/.config/starship.toml)":/etc/starship.toml:ro -e STARSHIP_CONFIG=/etc/starship.toml"
command -v xhost >/dev/null 2>&1 && xhost +SI:localuser:"$USER" >/dev/null 2>&1

########################################################################
# global
########################################################################
export CONTAINER_ENGINE=podman
export DBX_CONTAINER_MANAGER=$CONTAINER_ENGINE
export DBX_CONTAINER_IMAGE="docker.io/library/debian:stable-slim"
export DBX_CONTAINER_ALWAYS_PULL="0"
export DBX_NON_INTERACTIVE="0"
export CONTAINER_IMAGE_ARCH_SUFFIX="$(uname -m | sed 's/^x86_64$//' | sed 's/^arm64$/-arm64/' | sed 's/^aarch64$/-arm64/')"

# If you're using just podman, you could uncomment this to have
# docker/podman clients work more cleanly together.
#
# command -v podman >/dev/null 2>&1 && \
#   [[ -n "$UID" ]] && \
#   [[ -e "/run/user/$UID/podman/podman.sock" ]] && \
#   export DOCKER_HOST="unix:///run/user/$UID/podman/podman.sock"
#
# Or, for macOS with podman machine:
#
# command -v podman >/dev/null 2>&1 && \
#   [[ -e "$HOME/.local/share/containers/podman/machine/podman-machine-default/podman.sock" ]] && \
#   export DOCKER_HOST="unix://$HOME/.local/share/containers/podman/machine/podman-machine-default/podman.sock"

########################################################################
# aliases and helper functions for docker / podman
########################################################################

########################################################################
# media
########################################################################

# spotify (jess/spotify) via x11docker
function spotify() {
  mkdir -p "$HOME/.config/spotify/config" "$HOME/.config/spotify/cache"
  nohup x11docker --backend=$CONTAINER_ENGINE --network --hostuser=$USER --pulseaudio -- "-v" "$HOME/.config/spotify/config:/home/spotify/.config/spotify" "-v" "$HOME/.config/spotify/cache:/home/spotify/spotify" -- jess/spotify </dev/null >/dev/null 2>&1 &
}

# audacity (oci.guero.org/audacity) via x11docker
function audacityd() {
  DOCS_FOLDER="$(realpath $(pwd))"
  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      DOCS_FOLDER="$(dirname "$(realpath "$1")")"
    elif [[ -d "$1" ]]; then
      DOCS_FOLDER="$(realpath "$1")"
    fi
  fi
  if [[ "$(realpath "$DOCS_FOLDER")" == "$(realpath "$HOME")" ]]; then
    echo "\$DOCS_FOLDER needs to be a directory other than \"$HOME\"" >&2
  else
    x11docker --backend=$CONTAINER_ENGINE --pulseaudio --alsa --workdir=/Audio -- "-v" "$DOCS_FOLDER:/Audio" -- oci.guero.org/audacity:latest${CONTAINER_IMAGE_ARCH_SUFFIX}
  fi
}

# losslesscut (oci.guero.org/lossless-cut) via x11docker
function losslesscut() {
  DOCS_FOLDER="$(realpath $(pwd))"
  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      DOCS_FOLDER="$(dirname "$(realpath "$1")")"
    elif [[ -d "$1" ]]; then
      DOCS_FOLDER="$(realpath "$1")"
    fi
  fi
  if [[ "$(realpath "$DOCS_FOLDER")" == "$(realpath "$HOME")" ]]; then
    echo "\$DOCS_FOLDER needs to be a directory other than \"$HOME\"" >&2
  else
    nohup x11docker --no-entrypoint --backend=$CONTAINER_ENGINE --pulseaudio --gpu --workdir=/Videos -- "-v" "$DOCS_FOLDER:/Videos" -- oci.guero.org/lossless-cut:latest${CONTAINER_IMAGE_ARCH_SUFFIX} /opt/LosslessCut-linux-x64/losslesscut --no-sandbox </dev/null >/dev/null 2>&1 &
  fi
}

function fluentbit() {
  DIR="$(pwd)"

  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    CONTAINER_PUID=0
    CONTAINER_PGID=0
  else
    CONTAINER_PUID=$(id -u)
    CONTAINER_PGID=$(id -g)
  fi

  if $CONTAINER_ENGINE cis 2>/dev/null | grep -q fluent/fluent-bit >/dev/null 2>&1; then
    $CONTAINER_ENGINE run -i -t --rm \
      -u $CONTAINER_PUID:$CONTAINER_PGID \
      -v "$DIR:$DIR:rw" \
      -w "$DIR" \
      cr.fluentbit.io/fluent/fluent-bit:latest "$@"

  else
    echo "Please pull either cr.fluentbit.io/fluent/fluent-bit:latest" >&2
  fi
}
function fluentbitd() { CONTAINER_ENGINE=docker fluentbit "$@"; }
function fluentbitp() { CONTAINER_ENGINE=podman fluentbit "$@"; }

# ffmpeg (mwader/static-ffmpeg or linuxserver/ffmpeg) containerized
function ffmpegc() {
  DIR="$(pwd)"

  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    CONTAINER_PUID=0
    CONTAINER_PGID=0
  else
    CONTAINER_PUID=$(id -u)
    CONTAINER_PGID=$(id -g)
  fi

  if $CONTAINER_ENGINE cis 2>/dev/null | grep -q mwader/static-ffmpeg >/dev/null 2>&1; then
    $CONTAINER_ENGINE run -i -t --rm \
      -u $CONTAINER_PUID:$CONTAINER_PGID \
      -v "$DIR:$DIR:rw" \
      -w "$DIR" \
      mwader/static-ffmpeg "$@"

  elif $CONTAINER_ENGINE cis 2>/dev/null | grep -q linuxserver/ffmpeg >/dev/null 2>&1; then
    $CONTAINER_ENGINE run -i -t --rm \
      -e PUID=$CONTAINER_PUID \
      -e PGID=$CONTAINER_PGID \
      -v "$DIR:$DIR:rw" \
      -w "$DIR" \
      linuxserver/ffmpeg "$@"

  else
    echo "Please pull either mwader/static-ffmpeg or linuxserver/ffmpeg" >&2
  fi
}
function ffmpegd() { CONTAINER_ENGINE=docker ffmpegc "$@"; }
function ffmpegp() { CONTAINER_ENGINE=podman ffmpegc "$@"; }

# yt-dlp (mmguero/yt-dlp) containerized
function ytdlpc() {
  DIR="$(pwd)"

  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    CONTAINER_PUID=0
    CONTAINER_PGID=0
  else
    CONTAINER_PUID=$(id -u)
    CONTAINER_PGID=$(id -g)
  fi

  $CONTAINER_ENGINE run -i -t --rm \
    -e PUID=$CONTAINER_PUID \
    -e PGID=$CONTAINER_PGID \
    -v "$DIR:$DIR:rw" \
    -w "$DIR" \
    --pull=never \
    oci.guero.org/yt-dlp:latest${CONTAINER_IMAGE_ARCH_SUFFIX} "$@"
}
function ytdlpd() { CONTAINER_ENGINE=docker ytdlpc "$@"; }
function ytdlpp() { CONTAINER_ENGINE=podman ytdlpc "$@"; }

function ytmusicc() {
  format="$1"
  search="$2"
  quality="${3:-2}"
  if [[ "$search" =~ ^http ]]; then
    ytdlpc -f bestaudio --extract-audio --audio-format "$format" --audio-quality $quality -q --max-downloads 1 "$search"
  else
    ytdlpc -f bestaudio --extract-audio --audio-format "$format" --audio-quality $quality -q --max-downloads 1 --no-playlist --default-search ytsearch "$search"
  fi
}
function ytmusicd() { CONTAINER_ENGINE=docker ytmusicc "$@"; }
function ytmusicp() { CONTAINER_ENGINE=podman ytmusicc "$@"; }

function ytmp3c() { ytmusicc mp3 "$@"; }
function ytmp3d() { CONTAINER_ENGINE=docker ytmp3c "$@"; }
function ytmp3p() { CONTAINER_ENGINE=podman ytmp3c "$@"; }

function ytoggc() { ytmusicc vorbis "$@"; }
function ytoggd() { CONTAINER_ENGINE=docker ytoggc "$@"; }
function ytoggp() { CONTAINER_ENGINE=podman ytoggc "$@"; }

function ytplaylistc() {
  format="$1"
  quality="$2"
  playlist="$3"
  ytdlpc -f bestaudio --extract-audio --audio-format "$format" --audio-quality $quality "$playlist"
}
function ytplaylistd() { CONTAINER_ENGINE=docker ytplaylistc "$@"; }
function ytplaylistp() { CONTAINER_ENGINE=podman ytplaylistc "$@"; }

function ytplaylistoggd() { ytplaylistd vorbis 2 "$@"; }
function ytplaylistoggp() { ytplaylistp vorbis 2 "$@"; }

function ytplaylistmp3d() { ytplaylistd mp3 2 "$@"; }
function ytplaylistmp3p() { ytplaylistp mp3 2 "$@"; }

########################################################################
# kubernetes
########################################################################
if [[ -f /usr/local/bin/k3s ]]; then
  alias k3s="sudo /usr/local/bin/k3s"
  alias kubectl="sudo /usr/local/bin/kubectl"
  alias crictl="sudo /usr/local/bin/crictl"
fi
command -v kubectl >/dev/null 2>&1 && alias k=kubectl
alias k9s='k9s --logoless --splashless'

function kctl () {
  if [[ -n "${KUBECONFIG}" ]]; then
    kubectl --kubeconfig "${KUBECONFIG}" "$@"
  else
    kubectl "$@"
  fi
}

function kstern () {
  if [[ -n "${KUBECONFIG}" ]]; then
    stern --kubeconfig "${KUBECONFIG}" "$@"
  else
    stern "$@"
  fi
}

function kpods () {
  NAMESPACE="${1:-$KUBESPACE}"
  if [[ -n "$NAMESPACE" ]]; then
    NAMESPACE_ARGS=( --namespace "${NAMESPACE}" )
  else
    NAMESPACE_ARGS=( --all-namespaces )
  fi
  kctl get pods --no-headers "${NAMESPACE_ARGS[@]}"
}

function kshell () {
  SERVICE="${1}"
  if [[ -n "${SERVICE}" ]]; then
    NAMESPACE="${2:-$KUBESPACE}"
    if [[ -n "$NAMESPACE" ]]; then
      NAMESPACE_ARGS=( --namespace "${NAMESPACE}" )
      AWK_ARGS=( '{print $1}' )
    else
      NAMESPACE_ARGS=( --all-namespaces )
      AWK_ARGS=( '{print $2}' )
    fi
    SHELL="${3:-/bin/bash}"
    POD="$(kctl get pods --no-headers "${NAMESPACE_ARGS[@]}" | grep -P "\b${SERVICE}\b" | awk "${AWK_ARGS[@]}" | sort | head -n 1)"
    if [[ -n "${POD}" ]]; then
        kctl exec "${NAMESPACE_ARGS[@]}" --stdin --tty "${POD}" -- "${SHELL}"
    else
        echo "Unable to identify pod for ${SERVICE}" >&2
    fi
  else
    echo "No service specified" >&2
  fi
}

function klogs () {
  SERVICE="${1:-}"

  NAMESPACE="${2:-$KUBESPACE}"
  if [[ -n "$NAMESPACE" ]]; then
    NAMESPACE_ARGS=( --namespace "${NAMESPACE}" )
    AWK_ARGS=( '{print $1}' )
  else
    NAMESPACE_ARGS=( --all-namespaces )
    AWK_ARGS=( '{print $2}' )
  fi

  [[ -n "${SERVICE}" ]] && \
    POD="$(kctl get pods --no-headers "${NAMESPACE_ARGS[@]}" | grep -P "\b${SERVICE}\b" | awk "${AWK_ARGS[@]}" | sort | head -n 1)" || \
    POD=

  if command -v stern >/dev/null 2>&1; then
      kstern "${POD:-.*}" "${NAMESPACE_ARGS[@]}" --container '.*' --container-state all
  else
    [[ -n "${POD}" ]] && \
      kctl logs --follow=true --all-containers "${POD}" "${NAMESPACE_ARGS[@]}" ||
      echo "Unable to identify ${SERVICE} pod " >&2
  fi
}

function kresources () {
    NAMESPACE="${1:-$KUBESPACE}"
    if [[ -n "$NAMESPACE" ]]; then
      NAMESPACE_ARGS=( --namespace "${NAMESPACE}" )
    else
      NAMESPACE_ARGS=( --all-namespaces )
    fi
    for RESOURCE in $(kubectl api-resources --verbs=list --namespaced -o name); do
      if [[ ! "$RESOURCE" =~ ^events.* ]]; then
        readarray -t KCTL_OUTPUT < <(kctl get --ignore-not-found "${NAMESPACE_ARGS[@]}" "$RESOURCE")
        if [[ ${#KCTL_OUTPUT[@]} -gt 0 ]]; then
          echo "============================="
          echo "${RESOURCE}"
          echo "-----------------------------"
          printf '%s\n' "${KCTL_OUTPUT[@]}"
        fi
      fi
    done
}

########################################################################
# communications
########################################################################
#function zoom() {
#  # https://hub.docker.com/r/mdouchement/zoom-us
#  if ! type zoom-us-wrapper >/dev/null 2>&1; then
#    mkdir -p "$HOME"/.local/bin
#    $CONTAINER_ENGINE pull mdouchement/zoom-us
#    $CONTAINER_ENGINE run -it --rm -u $CONTAINER_PUID:$CONTAINER_PGID --volume "$HOME"/.local/bin:/target mdouchement/zoom-us install
#  fi
#  zoom-us-wrapper zoom
#}

#function teams() {
#  nohup x11docker --backend=$CONTAINER_ENGINE --network --gpu --alsa --webcam --hostuser=$USER --workdir=/usr/share/teams -- "--tmpfs" "/dev/shm" -- oci.guero.org/teams:latest${CONTAINER_IMAGE_ARCH_SUFFIX} "$@" </dev/null >/dev/null 2>&1 &
#}

# signal (oci.guero.org/signal) via x11docker
function signal() {
  mkdir -p "$HOME/.config/Signal"
  # --pulseaudio --webcam
  nohup x11docker --backend=$CONTAINER_ENGINE --network --hostuser=$USER --workdir=/opt/Signal -- "-v" "$HOME/.config/Signal:/home.tmp/$USER/.config/Signal" -- oci.guero.org/signal:latest${CONTAINER_IMAGE_ARCH_SUFFIX} </dev/null >/dev/null 2>&1 &
}

########################################################################
# web
########################################################################
# cyberchef (mpepping/cyberchef) containerized
function cyberchef() {
  CHEF_PORT="${1:-8000}"
  $CONTAINER_ENGINE run -d --rm -p $CHEF_PORT:8000 --name cyberchef --pull=never mpepping/cyberchef && \
  o http://localhost:$CHEF_PORT
}

function carbonyl() {
  ENGINE="${CONTAINER_ENGINE:-docker}"

  DOWNLOAD_DIR="$(type xdg-user-dir >/dev/null 2>&1 && xdg-user-dir DOWNLOAD || echo "$HOME/Downloads")"

  mkdir -p "$DOWNLOAD_DIR"

  # for audio with pulse it's sort of a pain. i haven't been able to get auth to work right, however this works:
  # 1. install paprefs
  # 2. Network Server tab
  #    - Enable network access to local sound devices
  #    - Don't require authentication
  # 3. Use a firewall so as to not allow 4713 from other than localhost

  $ENGINE run -ti --rm \
    --net=host \
    -v "$DOWNLOAD_DIR:/home/carbonyl/Downloads" \
    -v /dev/shm:/dev/shm \
    -v /etc/machine-id:/etc/machine-id:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v /etc/timezone:/etc/timezone:ro \
    -e TZ="$(head -n 1 /etc/timezone)" \
    -e PULSE_SERVER=tcp:localhost:4713 \
    --name carbonyl \
    docker.io/fathyb/carbonyl:latest "$@"
}

########################################################################
# network misc.
########################################################################

function cssh() {
  DIR="$(pwd)"

  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    CONTAINER_PUID=0
    CONTAINER_PGID=0
  else
    CONTAINER_PUID=$(id -u)
    CONTAINER_PGID=$(id -g)
  fi

  $CONTAINER_ENGINE run -i -t --rm \
    -e PUID=$CONTAINER_PUID \
    -e PGID=$CONTAINER_PGID \
    -u $CONTAINER_PUID:$CONTAINER_PGID \
    -v "$DIR:$DIR:rw" \
    $CONTAINER_SHARE_SSH \
    -w "$DIR" \
    --pull=never \
    --entrypoint=ssh \
    oci.guero.org/debian:latest${CONTAINER_IMAGE_ARCH_SUFFIX} \
    -F "$CONTAINER_SHARE_HOME"/.ssh/config \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$@"
}
function dssh() { CONTAINER_ENGINE=docker cssh "$@"; }
function pssh() { CONTAINER_ENGINE=podman cssh "$@"; }

function cclient() {
  DIR="$(pwd)"

  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    CONTAINER_PUID=0
    CONTAINER_PGID=0
  else
    CONTAINER_PUID=$(id -u)
    CONTAINER_PGID=$(id -g)
  fi

  if [[ "$1" ]]; then
    CLIENT_EXE="$1"
    shift
  fi

  $CONTAINER_ENGINE run -i -t --rm \
    -e PUID=$CONTAINER_PUID \
    -e PGID=$CONTAINER_PGID \
    -u $CONTAINER_PUID:$CONTAINER_PGID \
    -v "$DIR:$DIR:rw" \
    -w "$DIR" \
    --pull=never \
    --entrypoint="$CLIENT_EXE" \
    oci.guero.org/debian:latest${CONTAINER_IMAGE_ARCH_SUFFIX} \
    "$@"
}
function dclient() { CONTAINER_ENGINE=docker cclient "$@"; }
function pclient() { CONTAINER_ENGINE=podman cclient "$@"; }

########################################################################
# desktop
########################################################################
# full XFCE-based desktop (oci.guero.org/xfce) via x11docker
function x11desktop() {
  if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
    nohup x11docker \
      --nxagent \
      --backend=$CONTAINER_ENGINE \
      --network \
      --clipboard \
      --dbus \
      --desktop \
      --home \
      --network=host \
      --printer \
      --pulse \
      --webcam \
      --share /var/run/libvirt/ \
      --share /var/run/docker.sock \
      --group-add=docker \
      --group-add=fuse \
      --group-add=libvirt \
    oci.guero.org/xfce:latest${CONTAINER_IMAGE_ARCH_SUFFIX} </dev/null >/dev/null 2>&1 &

  elif [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    nohup x11docker \
      --nxagent \
      --backend=$CONTAINER_ENGINE \
      --network \
      --clipboard \
      --dbus \
      --desktop \
      --home \
      --network=host \
      --printer \
      --pulse \
      --webcam \
      --share /var/run/libvirt/ \
      --group-add=fuse \
      --group-add=libvirt \
    oci.guero.org/xfce:latest${CONTAINER_IMAGE_ARCH_SUFFIX} </dev/null >/dev/null 2>&1 &

  else
    echo "\$CONTAINER_ENGINE invalid or unspecified" >&2
  fi
}

function ciso_ports_format() {
  CONTAINER_NAME=
  CONTAINER_ENGINE=$1
  CONTAINER_ID=$2
  [[ -n "$CONTAINER_ID" ]] && \
    command -v jq >/dev/null 2>&1 && \
    CONTAINER_NAME=$($CONTAINER_ENGINE inspect $CONTAINER_ID | jq -r '.[0].Name')
  [[ -n "$CONTAINER_NAME" ]] || CONTAINER_NAME=$CONTAINER_ID
  echo -e "Name:\t\t$CONTAINER_NAME"
  command -v jq >/dev/null 2>&1 && \
    $CONTAINER_ENGINE inspect $CONTAINER_ID | \
    jq -r '.[0].NetworkSettings.Ports | to_entries[] | "\(.key)=\(.value[].HostPort)"' | \
    grep -v "^22/tcp" | \
    sed "s@5900/tcp=@VNC:\t\tvnc://localhost:@" | \
    sed "s@8000/tcp=@Download:\thttp://localhost:@" | \
    sed "s@8081/tcp=@Web View:\thttp://localhost:@"
}

# run an ISO in QEMU-KVM (oci.guero.org/qemu-live-iso)
function ciso() {
    if [[ -e /dev/kvm ]]; then
        if [[ "$1" ]]; then
          ciso_ports_format $CONTAINER_ENGINE $($CONTAINER_ENGINE run \
            --detach \
            --publish-all \
            --rm \
            -e QEMU_CPU=${QEMU_CPU:-2} \
            -e QEMU_RAM=${QEMU_RAM:-4096} \
            --device /dev/kvm \
            --volume "$(realpath "$1")":/image/live.iso:ro \
            --pull=never \
            oci.guero.org/qemu-live-iso:latest${CONTAINER_IMAGE_ARCH_SUFFIX})
        else
            echo "No image file specified" >&2
        fi
    else
        echo "/dev/kvm not found" >&2
    fi
}
function diso() { CONTAINER_ENGINE=docker ciso "$@"; }
function piso() { CONTAINER_ENGINE=podman ciso "$@"; }

# run oci.guero.org/deblive in QEMU-KVM
function deblive() {
    if [[ -e /dev/kvm ]]; then
      ciso_ports_format $CONTAINER_ENGINE $($CONTAINER_ENGINE run \
      --detach \
      --publish-all \
      --rm \
      -e QEMU_CPU=${QEMU_CPU:-2} \
      -e QEMU_RAM=${QEMU_RAM:-4096} \
      -e QEMU_CDROM=/image/live.iso \
      --device /dev/kvm \
      --pull=never \
      oci.guero.org/deblive:latest${CONTAINER_IMAGE_ARCH_SUFFIX})
    else
      echo "/dev/kvm not found" >&2
    fi
}
function deblived() { CONTAINER_ENGINE=docker deblive "$@"; }
function deblivep() { CONTAINER_ENGINE=podman deblive "$@"; }

########################################################################
# helper functions for docker / podman
########################################################################

function cstopped(){
  local name=$1
  local state
  state=$($CONTAINER_ENGINE inspect --format "{{.State.Running}}" "$name" 2>/dev/null)

  if [[ "$state" == "false" ]]; then
    $CONTAINER_ENGINE rm "$name"
  fi
}
function dstopped() { CONTAINER_ENGINE=docker cstopped "$@"; }
function pstopped() { CONTAINER_ENGINE=podman cstopped "$@"; }

# clean dangling build artifacts, images, leftover containers, etc.
function cclean() {
    $CONTAINER_ENGINE rm -v $($CONTAINER_ENGINE ps --filter status=exited -q 2>/dev/null) 2>/dev/null
    $CONTAINER_ENGINE rmi $($CONTAINER_ENGINE images --filter dangling=true -q 2>/dev/null) 2>/dev/null
    $CONTAINER_ENGINE buildx prune -f 2>/dev/null
    $CONTAINER_ENGINE network prune -f 2>/dev/null
}
function dclean() { CONTAINER_ENGINE=docker cclean "$@"; }
function pclean() { CONTAINER_ENGINE=podman cclean "$@"; }

# run a new container and remove it when done
function crun() {
  $CONTAINER_ENGINE run -t -i -P --rm \
    -e HISTFILE=/tmp/.bash_history \
    -e GITHUB_TOKEN \
    $CONTAINER_SHARE_TMP \
    $CONTAINER_SHARE_BASH_RC \
    $CONTAINER_SHARE_BASH_RC_D \
    $CONTAINER_SHARE_BASH_ALIASES \
    $CONTAINER_SHARE_BASH_FUNCTIONS \
    $CONTAINER_SHARE_GIT_CONFIG \
    $CONTAINER_SHARE_STARSHIP_CONFIG \
    --pull=never \
    "$@"
}
function drun() { CONTAINER_ENGINE=docker crun "$@"; }
function prun() { CONTAINER_ENGINE=podman crun "$@"; }

function debian() { crun "$@" oci.guero.org/debian:latest${CONTAINER_IMAGE_ARCH_SUFFIX}; }
function debiand() { CONTAINER_ENGINE=docker crun "$@" oci.guero.org/debian:latest${CONTAINER_IMAGE_ARCH_SUFFIX}; }
function debianp() { CONTAINER_ENGINE=podman crun "$@" oci.guero.org/debian:latest${CONTAINER_IMAGE_ARCH_SUFFIX}; }

# compose
# the "podman compose" help says:
#   This command is a thin wrapper around an external compose provider such as docker-compose
#     or podman-compose.  This means that podman compose is executing another tool that
#     implements the compose functionality but sets up the environment in a way to let the
#     compose provider communicate transparently with the local Podman socket.
#     The specified options as well the command and argument are passed directly to the compose provider.
#   The default compose providers are docker-compose and podman-compose.  If installed, docker-compose
#     takes precedence since it is the original implementation of the Compose specification and is
#     widely used on the supported platforms.
# In other words, I can just call $CONTAINER_ENGINE compose and have it do the right thing.
function dc() { docker compose "$@"; }
function pc() { podman compose "$@" 2> >(grep -v 'Executing external compose provider' >&2); }

# Get latest container ID
function clid() { $CONTAINER_ENGINE ps -l -q "$@"; }
function dl() { CONTAINER_ENGINE=docker clid "$@"; }
function pl() { CONTAINER_ENGINE=podman clid "$@"; }

# Get container process
function cps() { $CONTAINER_ENGINE ps "$@"; }
function dps() { CONTAINER_ENGINE=docker cps "$@"; }
function pps() { CONTAINER_ENGINE=podman cps "$@"; }

# Get process included stop container
function cpa() { $CONTAINER_ENGINE ps -a "$@"; }
function dpa() { CONTAINER_ENGINE=docker cpa "$@"; }
function ppa() { CONTAINER_ENGINE=podman cpa "$@"; }

# List images without details (just names)
function cis() {
  if command -v jq >/dev/null 2>&1; then
      case "$CONTAINER_ENGINE" in
        docker)
          FORMAT_STRING='{{json .}}'
          JQ_ADAPTER='
            (
              {
                repo: .Repository,
                tag: .Tag
              }
            )
          '
          ;;
        podman)
          FORMAT_STRING='{{json .}}'
          JQ_ADAPTER='
            (
              {
                repo: .repository,
                tag: .tag
              }
            )
          '
          ;;
        *)
          echo "Unknown container engine: $CONTAINER_ENGINE" >&2
          return 1
          ;;
      esac

      $CONTAINER_ENGINE images --format "$FORMAT_STRING" "$@" |
        jq -r "
          $JQ_ADAPTER |
          \"\(.repo):\(.tag)\"
        " |
        sort

    else
      case "$CONTAINER_ENGINE" in
        docker)
          AWK_FILTER='{print $1}'
          ;;
        podman)
          AWK_FILTER='{print $1":"$2}'
          ;;
        *)
          echo "Unknown container engine: $CONTAINER_ENGINE" >&2
          return 1
          ;;
      esac
      $CONTAINER_ENGINE images "$@" 2>/dev/null | tail -n +2 | sort | awk "$AWK_FILTER"
    fi
}
function dis() { CONTAINER_ENGINE=docker cis "$@"; }
function pis() { CONTAINER_ENGINE=podman cis "$@"; }

# List images with details
function ci() {
  if command -v jq >/dev/null 2>&1; then
    case "$CONTAINER_ENGINE" in
      docker)
        FORMAT_STRING='{{json .}}'
        JQ_ADAPTER='
          (
            {
              repo: .Repository,
              tag: .Tag,
              id: (.ID | sub("^sha256:";"")[:12]),
              created: .CreatedSince,
              size: .Size
            }
          )
        '
        ;;
      podman)
        FORMAT_STRING='{"repository":"{{.Repository}}","tag":"{{.Tag}}","id":"{{.ID}}","created":"{{.CreatedSince}}","size":"{{.Size}}"}'
        JQ_ADAPTER='
          (
            {
              repo: .repository,
              tag: .tag,
              id: (.id | sub("^sha256:";"")[:12]),
              created: .created,
              size: .size
            }
          )
        '
        ;;
      *)
        echo "Unknown container engine: $CONTAINER_ENGINE" >&2
        return 1
        ;;
    esac

    $CONTAINER_ENGINE images --format "$FORMAT_STRING" "$@" |
      jq -r "
        $JQ_ADAPTER |
        [ .repo, .tag, .id, .created, .size ] |
        # Join the array elements with a Tab character (\t)
        map(tostring) | join(\"\\t\")
      " | tac |
      column -t -s$'\t' \
        -N "REPOSITORY","TAG","IMAGE ID","CREATED","SIZE"

  else
    $CONTAINER_ENGINE images "$@" 2>/dev/null | tail -n +2 | tac
  fi
}
function di() { CONTAINER_ENGINE=docker ci "$@"; }
function pi() { CONTAINER_ENGINE=podman ci "$@"; }

# Get container IP
function cip()   { $CONTAINER_ENGINE inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$@"; }
function dip()   { CONTAINER_ENGINE=docker cip "$@"; }
function podip() { CONTAINER_ENGINE=podman cip "$@"; }

# Execute in existing interactive container, e.g., dex base /bin/bash
function cex() { $CONTAINER_ENGINE exec -i -t "$@"; }
function dex() { CONTAINER_ENGINE=docker cex "$@"; }
function pex() { CONTAINER_ENGINE=podman cex "$@"; }

# a slimmed-down stats
function cstats() { $CONTAINER_ENGINE stats --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' "$@"; }
function dstats() { CONTAINER_ENGINE=docker cstats "$@"; }
function pstats() { CONTAINER_ENGINE=podman cstats "$@"; }

# container health (if health check is provided)
function chealth() {
  for CONTAINER in "$@"; do
    $CONTAINER_ENGINE inspect --format "{{json .State.Health }}" "$CONTAINER" | python3 -mjson.tool
  done
}
function dhealth() { CONTAINER_ENGINE=docker chealth "$@"; }
function phealth() { CONTAINER_ENGINE=podman chealth "$@"; }

# backup *all* images!
function docker_backup() {
  for IMAGE in $(dis | grep -Pv "(<none>|malcolm)"); do
    export FN=$(echo "$IMAGE" | sed -e 's/[^A-Za-z0-9._-]/_/g')
    docker save "$IMAGE" | pv | pigz > "$FN.tgz"
  done
}
function podman_backup() {
  for IMAGE in $(pis | grep -Pv "(<none>|malcolm)"); do
    export FN=$(echo "$IMAGE" | sed -e 's/[^A-Za-z0-9._-]/_/g')
    podman save --format oci-archive "$IMAGE" | pv | pigz > "$FN.tgz"
  done
}

# pull updates for images
function contup() {
  cis | grep -Piv "(<none>|facefusion|mimic|monkeyplug|malcolm)" | xargs -r -l $CONTAINER_ENGINE pull
}
function dockup() { CONTAINER_ENGINE=docker contup "$@"; }
function podup()  { CONTAINER_ENGINE=podman contup "$@"; }

# run a command in the last container launched
function cxl() {
  CONTAINER=$($CONTAINER_ENGINE ps -l -q)
  $CONTAINER_ENGINE exec -i -t $CONTAINER "$@"
}
function dxl() { CONTAINER_ENGINE=docker cxl "$@"; }
function pxl() { CONTAINER_ENGINE=podman cxl "$@"; }

# list virtual networks
function cnl() { $CONTAINER_ENGINE network ls "$@"; }
function dnl() { CONTAINER_ENGINE=docker cnl "$@"; }
function pnl() { CONTAINER_ENGINE=podman cnl "$@"; }

# inspect virtual networks
function cnins() { $CONTAINER_ENGINE network inspect "$@"; }
function dnins() { CONTAINER_ENGINE=docker cnins "$@"; }
function pnins() { CONTAINER_ENGINE=podman cnins "$@"; }

# Stop all containers
function cstop() { $CONTAINER_ENGINE stop $($CONTAINER_ENGINE ps -a -q); }
function dstop() { CONTAINER_ENGINE=docker cstop "$@"; }
function pstop() { CONTAINER_ENGINE=podman cstop "$@"; }

# Dockerfile build, e.g., $dbuild tcnksm/test
function cbuild() { $CONTAINER_ENGINE build -t=$1 .; }
function dbuild() { CONTAINER_ENGINE=docker cbuild "$@"; }
function pbuild() { CONTAINER_ENGINE=podman cbuild "$@"; }

# list container registry
function dregls() { curl -k -X GET "https://"$1"/v2/_catalog"; }
function pregls() { dregls "$@"; }

# container visualization (docker only)
function dockviz () {
  if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
    "$CONTAINER_ENGINE" run --rm -it \
      -v /var/run/docker.sock:/var/run/docker.sock \
    nate/dockviz images --tree
  else
    echo "nate/dockviz requires docker (/var/run/docker.sock)" >&2
  fi
}
function dive () {
  if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
    $CONTAINER_ENGINE run --rm -it \
      -v /var/run/docker.sock:/var/run/docker.sock \
      --pull=never \
      ghcr.io/wagoodman/dive:latest "$@"
  else
    echo "wagoodman/dive requires docker (/var/run/docker.sock)" >&2
  fi
}
