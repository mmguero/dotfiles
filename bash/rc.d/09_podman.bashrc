########################################################################
# aliases and helper functions for podman
########################################################################
export CONTAINER_ENGINE=podman

########################################################################
# helper functions for podman
########################################################################

function pstopped(){
  local name=$1
  local state
  state=$(podman inspect --format "{{.State.Running}}" "$name" 2>/dev/null)

  if [[ "$state" == "false" ]]; then
    podman rm "$name"
  fi
}

function pclean() {
    podman rm -v $(podman ps --filter status=exited -q 2>/dev/null) 2>/dev/null
    podman rmi $(podman images --filter dangling=true -q 2>/dev/null) 2>/dev/null
}

# run a new container and remove it when done
function prun() {
  podman run -t -i -P --rm \
    -e HISTFILE=/tmp/.bash_history \
    $DOCKER_SHARE_TMP $DOCKER_SHARE_BASH_RC $DOCKER_SHARE_BASH_ALIASES $DOCKER_SHARE_BASH_FUNCTIONS $DOCKER_SHARE_GIT_CONFIG \
    "$@"
}

# podman compose
alias pc="podman-compose"

# Get latest container ID
alias pl="podman ps -l -q"

# Get container process
alias pps="podman ps"

# Get process included stop container
alias ppa="podman ps -a"

# Get images
alias pi="podman images | tail -n +2 | tac"
alias pis="podman images | tail -n +2 | tac | cols 1 2 | sed \"s/ /:/\""

# Get container IP
alias pip="podman inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"

# Execute in existing interactive container, e.g., $dex base /bin/bash
alias pex="podman exec -i -t"

# a slimmed-down stats
alias pstats="podman stats --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'"

# container health (if health check is provided)
function phealth() {
  for CONTAINER in "$@"; do
    podman inspect --format "{{json .State.Health }}" "$CONTAINER" | python3 -mjson.tool
  done
}

# backup *all* podman images!
function podman_backup() {
  for IMAGE in $(dis | grep -Pv "(podman-osx|android-build-box|malcolmnetsec)"); do export FN=$(echo "$IMAGE" | sed -e 's/[^A-Za-z0-9._-]/_/g') ; podman save "$IMAGE" | pv | pigz > "$FN.tgz"  ; done
}

# pull updates for podman images
function podup() {
  di | grep -Piv "(malcolmnetsec)/" | cols 1 2 | tr ' ' ':' | xargs -r -l podman pull
}

function pxl() {
  CONTAINER=$(podman ps -l -q)
  podman exec -i -t $CONTAINER "$@"
}

# list virtual networks
alias pnl="podman network ls"

# inspect virtual networks
alias pnins="podman network inspect $@"

# Stop all containers
function pstop() { podman stop $(podman ps -a -q); }

# Dockerfile build, e.g., $dbu tcnksm/test
function pbuild() { podman build -t=$1 .; }

function pregls () {
  curl -k -X GET "https://"$1"/v2/_catalog"
}
