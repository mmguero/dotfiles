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
export DBX_NON_INTERACTIVE="0"

# If you're using just podman, you could uncomment this to have
# docker/podman clients work more cleanly together. See the
# compose() function for how I'm dealing with this for docker-compose
# specifically, which now supports docker-compose.
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

# audacity (ghcr.io/mmguero/audacity) via x11docker
function audacityd() {
  DOCS_FOLDER="$(realpath $(pwd))"
  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      DOCS_FOLDER="$(dirname "$(realpath "$1")")"
    elif [[ -d "$1" ]]; then
      DOCS_FOLDER="$(realpath "$1")"
    fi
  fi
  x11docker --backend=$CONTAINER_ENGINE --alsa $(find /dev/snd/ -type c | sed 's/^/--share /') --workdir=/Audio -- "-v" "$DOCS_FOLDER:/Audio" -- ghcr.io/mmguero/audacity
}

# losslesscut (ghcr.io/mmguero/lossless-cut) via x11docker
function losslesscut() {
  DOCS_FOLDER="$(realpath $(pwd))"
  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      DOCS_FOLDER="$(dirname "$(realpath "$1")")"
    elif [[ -d "$1" ]]; then
      DOCS_FOLDER="$(realpath "$1")"
    fi
  fi
  nohup x11docker --backend=$CONTAINER_ENGINE --pulseaudio --gpu --workdir=/Videos -- "-v" "$DOCS_FOLDER:/Videos" -- ghcr.io/mmguero/lossless-cut </dev/null >/dev/null 2>&1 &
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

  if $CONTAINER_ENGINE images 2>/dev/null | grep -q fluent/fluent-bit >/dev/null 2>&1; then
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

  if $CONTAINER_ENGINE images 2>/dev/null | grep -q mwader/static-ffmpeg >/dev/null 2>&1; then
    $CONTAINER_ENGINE run -i -t --rm \
      -u $CONTAINER_PUID:$CONTAINER_PGID \
      -v "$DIR:$DIR:rw" \
      -w "$DIR" \
      mwader/static-ffmpeg "$@"

  elif $CONTAINER_ENGINE images 2>/dev/null | grep -q linuxserver/ffmpeg >/dev/null 2>&1; then
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
    ghcr.io/mmguero/yt-dlp "$@"
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
#  nohup x11docker --backend=$CONTAINER_ENGINE --network --gpu --alsa --webcam --hostuser=$USER -- "--tmpfs" "/dev/shm" -- ghcr.io/mmguero/teams "$@" </dev/null >/dev/null 2>&1 &
#}

# signal (ghcr.io/mmguero/signal) via x11docker
function signal() {
  mkdir -p "$HOME/.config/Signal"
  # --pulseaudio --webcam
  nohup x11docker --backend=$CONTAINER_ENGINE --network --hostuser=$USER -- "-v" "$HOME/.config/Signal:/home.tmp/$USER/.config/Signal" -- ghcr.io/mmguero/signal </dev/null >/dev/null 2>&1 &
}

########################################################################
# web
########################################################################
# tor (jess/tor-browser) via x11docker
function tor() {
  nohup x11docker --backend=$CONTAINER_ENGINE --network --hostuser=$USER -- "--tmpfs" "/dev/shm" -- jess/tor-browser "$@" </dev/null >/dev/null 2>&1 &
}

# cyberchef (mpepping/cyberchef) containerized
function cyberchef() {
  CHEF_PORT="${1:-8000}"
  $CONTAINER_ENGINE run -d --rm -p $CHEF_PORT:8000 --name cyberchef --pull=never mpepping/cyberchef && \
  o http://localhost:$CHEF_PORT
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
    ghcr.io/mmguero/debian \
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
    ghcr.io/mmguero/debian \
    "$@"
}
function dclient() { CONTAINER_ENGINE=docker cclient "$@"; }
function pclient() { CONTAINER_ENGINE=podman cclient "$@"; }

########################################################################
# desktop
########################################################################
# kodi (erichough/kodi) via x11docker
function kodi() {
  if [[ "$1" ]]; then
    MEDIA_FOLDER="$1"
    shift
  else
    MEDIA_FOLDER="$(realpath $(pwd))"
  fi
  nohup x11docker --backend=$CONTAINER_ENGINE --home "$HOME/.config/kodi" --network --gpu --pulseaudio -- "-v"$MEDIA_FOLDER":/Media:ro" -- erichough/kodi "$@" </dev/null >/dev/null 2>&1 &
}

# full XFCE-based desktop (ghcr.io/mmguero/xfce) via x11docker
function x11desktop() {
  if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
    nohup x11docker \
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
    ghcr.io/mmguero/xfce </dev/null >/dev/null 2>&1 &

  elif [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    nohup x11docker \
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
    ghcr.io/mmguero/xfce </dev/null >/dev/null 2>&1 &

  else
    echo "\$CONTAINER_ENGINE invalid or unspecified" >&2
  fi
}

# run an ISO in QEMU-KVM (ghcr.io/mmguero/qemu-live-iso)
function ciso() {
    if [[ -e /dev/kvm ]]; then
        if [[ "$1" ]]; then
            $CONTAINER_ENGINE run \
            --detach \
            --publish-all \
            --rm \
            -e QEMU_CPU=${QEMU_CPU:-2} \
            -e QEMU_RAM=${QEMU_RAM:-4096} \
            --device /dev/kvm \
            --volume "$(realpath "$1")":/image/live.iso:ro \
            --pull=never \
            ghcr.io/mmguero/qemu-live-iso
        else
            echo "No image file specified" >&2
        fi
    else
        echo "/dev/kvm not found" >&2
    fi
}
function diso() { CONTAINER_ENGINE=docker ciso "$@"; }
function piso() { CONTAINER_ENGINE=podman ciso "$@"; }

# run ghcr.io/mmguero/deblive in QEMU-KVM
function deblive() {
    if [[ -e /dev/kvm ]]; then
      $CONTAINER_ENGINE run \
      --detach \
      --publish-all \
      --rm \
      -e QEMU_CPU=${QEMU_CPU:-2} \
      -e QEMU_RAM=${QEMU_RAM:-4096} \
      -e QEMU_CDROM=/image/live.iso \
      --device /dev/kvm \
      --pull=never \
      ghcr.io/mmguero/deblive
    else
      echo "/dev/kvm not found" >&2
    fi
}
function deblived() { CONTAINER_ENGINE=docker deblive "$@"; }
function deblivep() { CONTAINER_ENGINE=podman deblive "$@"; }

function debian() { crun "$@" ghcr.io/mmguero/debian; }
function debiand() { CONTAINER_ENGINE=docker crun "$@" ghcr.io/mmguero/debian; }
function debianp() { CONTAINER_ENGINE=podman crun "$@" ghcr.io/mmguero/debian; }

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

# compose
function compose() {
  OLD_DOCKER_HOST="$DOCKER_HOST"
  [[ -n "$UID" ]] && \
    [[ -e "/run/user/$UID/$CONTAINER_ENGINE/$CONTAINER_ENGINE.sock" ]] && \
    export DOCKER_HOST="unix:///run/user/$UID/$CONTAINER_ENGINE/$CONTAINER_ENGINE.sock"

  # as podman now has docker-compose support, we'll default to that for either if available
  if command -v docker-compose >/dev/null 2>&1; then
      docker-compose "$@"
  else
    ${CONTAINER_ENGINE}-compose "$@"
  fi
  [[ -n "$OLD_DOCKER_HOST" ]] && export DOCKER_HOST="$OLD_DOCKER_HOST" || unset DOCKER_HOST
}
function dc() { CONTAINER_ENGINE=docker compose "$@"; }
function pc() { CONTAINER_ENGINE=podman compose "$@"; }

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
function cis() { $CONTAINER_ENGINE images "$@" | tail -n +2 | tac | cols 1 2 | sed "s/ /:/"; }
function dis() { CONTAINER_ENGINE=docker cis "$@"; }
function pis() { CONTAINER_ENGINE=podman cis "$@"; }

# List images with details
function ci() { $CONTAINER_ENGINE images "$@" | tail -n +2 | tac; }
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
  for IMAGE in $(docker images | tail -n +2 | cols 1 2 | sed "s/ /:/" | grep -Pv "(malcolmnetsec)"); do
    export FN=$(echo "$IMAGE" | sed -e 's/[^A-Za-z0-9._-]/_/g')
    docker save "$IMAGE" | pv | pigz > "$FN.tgz"
  done
}
function podman_backup() {
  for IMAGE in $(podman images | tail -n +2 | cols 1 2 | sed "s/ /:/"); do
    export FN=$(echo "$IMAGE" | sed -e 's/[^A-Za-z0-9._-]/_/g')
    podman save --format oci-archive "$IMAGE" | pv | pigz > "$FN.tgz"
  done
}

# pull updates for images
function contup() {
  $CONTAINER_ENGINE images | tail -n +2 | grep -Piv "(malcolmnetsec)/" | cols 1 2 | tr ' ' ':' | xargs -r -l $CONTAINER_ENGINE pull
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
      wagoodman/dive "$@"
  else
    echo "wagoodman/dive requires docker (/var/run/docker.sock)" >&2
  fi
}
