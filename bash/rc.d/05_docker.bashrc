unset DOCKER_HOST
export WINDOWS_USER=$USER
export DOCKER_SHARE_HOME=$HOME
if [ $MACOS ]; then
  export DOCKER_SHARE_TMP="-v $DOCKER_SHARE_HOME/tmp:/host:rw,Z"
  export DOCKER_SHARE_BASH_RC="-v $DOCKER_SHARE_HOME/.bashrc:/etc/bash.bashrc:ro,Z -v $DOCKER_SHARE_HOME/.bashrc.d:/etc/bashrc.d:ro,Z"
  export DOCKER_SHARE_BASH_ALIASES="-v $DOCKER_SHARE_HOME/.bash_aliases:/etc/bash.bash_aliases:ro,Z"
  export DOCKER_SHARE_BASH_FUNCTIONS="-v $DOCKER_SHARE_HOME/.bash_functions:/etc/bash.bash_functions:ro,Z"
  export DOCKER_SHARE_GIT_CONFIG="-v $DOCKER_SHARE_HOME/.gitconfig:/etc/gitconfig:ro,Z"

else
  export DOCKER_SHARE_TMP="-v $DOCKER_SHARE_HOME/tmp:/host:rw,Z"
  export DOCKER_SHARE_BASH_RC="-v $DOCKER_SHARE_HOME/.bashrc:/etc/bash.bashrc:ro,Z -v $DOCKER_SHARE_HOME/.bashrc.d:/etc/bashrc.d:ro,Z"
  export DOCKER_SHARE_BASH_ALIASES="-v $DOCKER_SHARE_HOME/.bash_aliases:/etc/bash.bash_aliases:ro,Z"
  export DOCKER_SHARE_BASH_FUNCTIONS="-v $DOCKER_SHARE_HOME/.bash_functions:/etc/bash.bash_functions:ro,Z"
  export DOCKER_SHARE_GIT_CONFIG="-v $DOCKER_SHARE_HOME/.gitconfig:/etc/gitconfig:ro,Z"
  xhost +SI:localuser:"$USER" >/dev/null 2>&1
fi

########################################################################
# aliases and helper functions for docker
########################################################################

########################################################################
# media
########################################################################
export MONKEYPLUG_DOCKER_IMAGE=ghcr.io/mmguero/monkeyplug:large
export VOSK_MODEL=/home/tlacuache/devel/github/mmguero/monkeyplug/src/monkeyplug/model
export ZEEK_DOCKER_IMAGE=ghcr.io/mmguero/zeek:plus

function spotify() {
  mkdir -p "$HOME/.config/spotify/config" "$HOME/.config/spotify/cache"
  nohup x11docker --hostuser=$USER --pulseaudio -- "-v" "$HOME/.config/spotify/config:/home/spotify/.config/spotify" "-v" "$HOME/.config/spotify/cache:/home/spotify/spotify" -- jess/spotify:latest </dev/null >/dev/null 2>&1 &
}

function audacityd() {
  DOCS_FOLDER="$(realpath $(pwd))"
  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      DOCS_FOLDER="$(dirname "$(realpath "$1")")"
    elif [[ -d "$1" ]]; then
      DOCS_FOLDER="$(realpath "$1")"
    fi
  fi
  x11docker --alsa $(find /dev/snd/ -type c | sed 's/^/--share /') --workdir=/Audio -- "-v" "$DOCS_FOLDER:/Audio" -- ghcr.io/mmguero/audacity:latest
}

function losslesscut() {
  DOCS_FOLDER="$(realpath $(pwd))"
  if [[ -n "$1" ]]; then
    if [[ -f "$1" ]]; then
      DOCS_FOLDER="$(dirname "$(realpath "$1")")"
    elif [[ -d "$1" ]]; then
      DOCS_FOLDER="$(realpath "$1")"
    fi
  fi
  nohup x11docker --pulseaudio --gpu --workdir=/Videos -- "-v" "$DOCS_FOLDER:/Videos" -- ghcr.io/mmguero/lossless-cut:latest </dev/null >/dev/null 2>&1 &
}

function ffmpegd() {
  DIR="$(pwd)"

  if docker images 2>/dev/null | grep -q ^mwader/static-ffmpeg >/dev/null 2>&1; then
    docker run -i -t --rm \
      -u $UID:$GROUPS \
      -v "$DIR:$DIR:rw" \
      -w "$DIR" \
      mwader/static-ffmpeg:latest "$@"

  elif docker images 2>/dev/null | grep -q ^linuxserver/ffmpeg >/dev/null 2>&1; then
    docker run -i -t --rm \
      -e PUID=$(id -u) \
      -e PGID=$(id -g) \
      -v "$DIR:$DIR:rw" \
      -w "$DIR" \
      linuxserver/ffmpeg:latest "$@"

  else
    echo "Please pull either mwader/static-ffmpeg or linuxserver/ffmpeg" >&2
  fi
}

########################################################################
# communications
########################################################################
function zoom() {
  # https://hub.docker.com/r/mdouchement/zoom-us
  if ! type zoom-us-wrapper >/dev/null 2>&1; then
    mkdir -p "$HOME"/.local/bin
    docker pull mdouchement/zoom-us:latest
    docker run -it --rm -u $(id -u):$(id -g) --volume "$HOME"/.local/bin:/target mdouchement/zoom-us:latest install
  fi
  zoom-us-wrapper zoom
}

function teams() {
  nohup x11docker --gpu --alsa --webcam --hostuser=$USER -- "--tmpfs" "/dev/shm" -- mmguero/teams:latest "$@" </dev/null >/dev/null 2>&1 &
}

function signal() {
  mkdir -p "$HOME/.config/Signal"
  # --pulseaudio --webcam
  nohup x11docker --hostuser=$USER -- "-v" "$HOME/.config/Signal:/home.tmp/$USER/.config/Signal" -- mmguero/signal:latest </dev/null >/dev/null 2>&1 &
}

########################################################################
# web
########################################################################
function tor() {
  nohup x11docker --hostuser=$USER -- "--tmpfs" "/dev/shm" -- jess/tor-browser:latest "$@" </dev/null >/dev/null 2>&1 &
}

function cyberchef() {
  docker run -d --rm -p 8000:8000 --name cyberchef mpepping/cyberchef:latest && \
  o http://localhost:8000
}

########################################################################
# desktop
########################################################################
function kodi() {
  if [ "$1" ]; then
    MEDIA_FOLDER="$1"
    shift
  else
    MEDIA_FOLDER="$(realpath $(pwd))"
  fi
  nohup x11docker --gpu --pulseaudio -- "-v"$MEDIA_FOLDER":/Media:ro" -- erichough/kodi "$@" </dev/null >/dev/null 2>&1 &
}

function x11desktop() {
  nohup x11docker \
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
  ghcr.io/mmguero/xfce-ext:latest </dev/null >/dev/null 2>&1 &
}

function dockeriso() {
    if [[ -e /dev/kvm ]]; then
        if [[ "$1" ]]; then
            docker run \
            --detach \
            --publish-all \
            --rm \
            -e QEMU_CPU=${QEMU_CPU:-2} \
            -e QEMU_RAM=${QEMU_CPU:-4096} \
            --device /dev/kvm \
            --volume "$(realpath "$1")":/image/live.iso:ro \
            ghcr.io/mmguero/qemu-live-iso:latest
        else
            echo "No image file specified" >&2
            exit 1
        fi
    else
        echo "/dev/kvm not found" >&2
        exit 1
    fi
}

########################################################################
# helper functions for docker
########################################################################

function dstopped(){
  local name=$1
  local state
  state=$(docker inspect --format "{{.State.Running}}" "$name" 2>/dev/null)

  if [[ "$state" == "false" ]]; then
    docker rm "$name"
  fi
}

function dclean() {
    docker rm -v $(docker ps --filter status=exited -q 2>/dev/null) 2>/dev/null
    docker rmi $(docker images --filter dangling=true -q 2>/dev/null) 2>/dev/null
}

# run a new container and remove it when done
function drun() {
  docker run -t -i -P --rm \
    -e HISTFILE=/tmp/.bash_history \
    $DOCKER_SHARE_TMP $DOCKER_SHARE_BASH_RC $DOCKER_SHARE_BASH_ALIASES $DOCKER_SHARE_BASH_FUNCTIONS $DOCKER_SHARE_GIT_CONFIG \
    "$@"
}

# docker compose
alias dc="docker-compose"

# Get latest container ID
alias dl="docker ps -l -q"

# Get container process
alias dps="docker ps"

# Get process included stop container
alias dpa="docker ps -a"

# Get images
alias di="docker images | tail -n +2 | tac"
alias dis="docker images | tail -n +2 | tac | cols 1 2 | sed \"s/ /:/\""

# Get container IP
alias dip="docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"

# Execute in existing interactive container, e.g., $dex base /bin/bash
alias dex="docker exec -i -t"

# a slimmed-down stats
alias dstats="docker stats --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}'"

# container health (if health check is provided)
function dhealth() {
  for CONTAINER in "$@"; do
    docker inspect --format "{{json .State.Health }}" "$CONTAINER" | python3 -mjson.tool
  done
}

# backup *all* docker images!
function docker_backup() {
  for IMAGE in $(dis | grep -Pv "(docker-osx|android-build-box|malcolmnetsec)"); do export FN=$(echo "$IMAGE" | sed -e 's/[^A-Za-z0-9._-]/_/g') ; docker save "$IMAGE" | pv | pigz > "$FN.tgz"  ; done
}

# pull updates for docker images
function dockup() {
  di | grep -Piv "(malcolmnetsec)/" | cols 1 2 | tr ' ' ':' | xargs -r -l docker pull
}

function dxl() {
  CONTAINER=$(docker ps -l -q)
  docker exec -i -t $CONTAINER "$@"
}

# list virtual networks
alias dnl="docker network ls"

# inspect virtual networks
alias dnins="docker network inspect $@"

# Stop all containers
function dstop() { docker stop $(docker ps -a -q); }

# Dockerfile build, e.g., $dbu tcnksm/test
function dbuild() { docker build -t=$1 .; }

function dregls () {
  curl -k -X GET "https://"$1"/v2/_catalog"
}

alias dockviz='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock nate/dockviz:latest images -t'

function dive () {
  docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    wagoodman/dive:latest "$@"
}