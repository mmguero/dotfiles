if [ $WINDOWS10 ]; then
  export WINDOWS_USER=$USER
  export DOCKER_HOST=tcp://localhost:2375
  export DOCKER_SHARE_HOME=C:/Users/$WINDOWS_USER
  export DOCKER_SHARE_TMP="-v $DOCKER_SHARE_HOME/tmp:/host:rw,Z"
  if [ -d /mnt/c/Users/$WINDOWS_USER/cloud/sync/config ]; then
    export DOCKER_SHARE_BASH_RC="-v C:/Users/$WINDOWS_USER/cloud/config/bash/rc:/etc/bash.bashrc:ro,Z -v C:/Users/$WINDOWS_USER/cloud/config/bash/rc.d:/etc/bashrc.d:ro,Z"
    export DOCKER_SHARE_BASH_ALIASES="-v C:/Users/$WINDOWS_USER/cloud/config/bash/aliases:/etc/bash.bash_aliases:ro,Z"
    export DOCKER_SHARE_BASH_FUNCTIONS="-v C:/Users/$WINDOWS_USER/cloud/config/bash/functions:/etc/bash.bash_functions:ro,Z"
    export DOCKER_SHARE_GIT_CONFIG="-v C:/Users/$WINDOWS_USER/cloud/config/git/gitconfig:/etc/gitconfig:ro,Z"
  else
    export DOCKER_SHARE_BASH_RC=""
    export DOCKER_SHARE_BASH_ALIASES=""
    export DOCKER_SHARE_BASH_FUNCTIONS=""
    export DOCKER_SHARE_GIT_CONFIG=""
  fi
  # eval $(docker-machine.exe env default --shell bash | sed 's?\\?/?g;s?C:/?/mnt/c/?g')

elif [ $MACOS ]; then
  unset DOCKER_HOST
  export WINDOWS_USER=$USER
  export DOCKER_SHARE_HOME=$HOME
  export DOCKER_SHARE_TMP="-v $DOCKER_SHARE_HOME/tmp:/host:rw,Z"
  export DOCKER_SHARE_BASH_RC="-v $DOCKER_SHARE_HOME/.bashrc:/etc/bash.bashrc:ro,Z -v $DOCKER_SHARE_HOME/.bashrc.d:/etc/bashrc.d:ro,Z"
  export DOCKER_SHARE_BASH_ALIASES="-v $DOCKER_SHARE_HOME/.bash_aliases:/etc/bash.bash_aliases:ro,Z"
  export DOCKER_SHARE_BASH_FUNCTIONS="-v $DOCKER_SHARE_HOME/.bash_functions:/etc/bash.bash_functions:ro,Z"
  export DOCKER_SHARE_GIT_CONFIG="-v $DOCKER_SHARE_HOME/.gitconfig:/etc/gitconfig:ro,Z"

else
  unset DOCKER_HOST
  export WINDOWS_USER=$USER
  export DOCKER_SHARE_HOME=$HOME
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
alias m4b-tool='docker run -it --rm -u $(id -u):$(id -g) -v "$(pwd)":/mnt m4b-tool'

function spotify() {
  mkdir -p "$HOME/.config/spotify/config" "$HOME/.config/spotify/cache"
  nohup x11docker --hostuser=$USER --pulseaudio -- "-v" "$HOME/.config/spotify/config:/home/spotify/.config/spotify" "-v" "$HOME/.config/spotify/cache:/home/spotify/spotify" -- jess/spotify </dev/null >/dev/null 2>&1 &
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
  nohup x11docker --hostuser=$USER -- "--tmpfs" "/dev/shm" -- jess/tor-browser "$@" </dev/null >/dev/null 2>&1 &
}

function cyberchef() {
  docker run -d --rm -p 8000:8000 --name cyberchef mpepping/cyberchef:latest && \
    xdg-open http://localhost:8000
}

########################################################################
# desktop
########################################################################
function x11desktop() {
  if [ "$1" ]; then
    DESKTOP_PROVIDER="$1"
    shift
  else
    DESKTOP_PROVIDER="lxde"
  fi
  if [[ "$DESKTOP_PROVIDER" == "mate" ]]; then
    INITFLAG="--init=systemd"
  else
    INITFLAG=""
  fi
  nohup x11docker --desktop --sudouser $INITFLAG --pulseaudio -- x11docker/$DESKTOP_PROVIDER "$@" </dev/null >/dev/null 2>&1 &
}

function chromiumd() {
  mkdir -p "$HOME/download"
  nohup x11docker --gpu --pulseaudio -- "-v" "$HOME/download:/Downloads" "--tmpfs" "/dev/shm" -- jess/chromium --no-sandbox "$@" </dev/null >/dev/null 2>&1 &
}

function firefoxd() {
  mkdir -p "$HOME/download"
  nohup x11docker --gpu --pulseaudio -- "-v" "$HOME/download:/Downloads" "--tmpfs" "/dev/shm" -- jess/firefox "$@" </dev/null >/dev/null 2>&1 &
}

function kodi() {
  if [ "$1" ]; then
    MEDIA_FOLDER="$1"
    shift
  else
    MEDIA_FOLDER="$(realpath $(pwd))"
  fi
  nohup x11docker --gpu --pulseaudio -- "-v"$MEDIA_FOLDER":/Media:ro" -- erichough/kodi "$@" </dev/null >/dev/null 2>&1 &
}

########################################################################
# helper functions for docker
########################################################################

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

# run a new container (with X11/pulse) and remove it when done
function drunx() {
  XSOCK=/tmp/.X11-unix
  XAUTH=/tmp/.docker.xauth
  touch $XAUTH
  xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
  docker run -t -i -P --rm \
    -v $XSOCK:$XSOCK:rw,Z \
    -v $XAUTH:$XAUTH:rw,Z \
    -e HISTFILE=/tmp/.bash_history \
    -e DISPLAY=$DISPLAY \
    -e XAUTHORITY=$XAUTH \
    -e PULSE_SERVER=tcp:$(/sbin/ifconfig docker0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'):4713 \
    -e PULSE_COOKIE=/run/pulse/cookie \
    $DOCKER_SHARE_TMP $DOCKER_SHARE_BASH_RC $DOCKER_SHARE_BASH_ALIASES $DOCKER_SHARE_BASH_FUNCTIONS $DOCKER_SHARE_GIT_CONFIG \
    -v $DOCKER_SHARE_HOME/.config/pulse/cookie:/run/pulse/cookie:rw,Z \
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
alias di="docker images | tail -n +2"
alias dis="docker images | tail -n +2 | cols 1 2 | sed \"s/ /:/\""

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
  for IMAGE in `dis`; do export FN=$(echo "$IMAGE" | sed -e 's/[^A-Za-z0-9._-]/_/g') ; docker save "$IMAGE" | pv | pigz > "$FN.tgz"  ; done
}

# pull updates for docker images
function dockup() {
  di | grep -Piv "(malcolmnetsec|x11docker|jess|mingc)/" | cols 1 2 | tr ' ' ':' | xargs -r -l docker pull
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

alias dockviz='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock nate/dockviz images -t'

function dive () {
  docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    wagoodman/dive:latest "$@"
}
