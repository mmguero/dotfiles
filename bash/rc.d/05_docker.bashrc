if [ $WINDOWS10 ]; then
  export WINDOWS_USER=tlacuache
  export DOCKER_HOST=tcp://localhost:2375
  export DOCKER_SHARE_HOME=C:/Users/$WINDOWS_USER
  export DOCKER_SHARE_TMP="-v $DOCKER_SHARE_HOME/tmp:/host:rw,Z"
  if [ -d /mnt/c/Users/$WINDOWS_USER/pCloud/sync/config ]; then
    export DOCKER_SHARE_BASH_RC="-v C:/Users/tlacuache/pcloud/config/bash/rc:/etc/bash.bashrc:ro,Z -v C:/Users/tlacuache/pcloud/config/bash/rc.d:/etc/bashrc.d:ro,Z"
    export DOCKER_SHARE_BASH_ALIASES="-v C:/Users/tlacuache/pcloud/config/bash/aliases:/etc/bash.bash_aliases:ro,Z"
    export DOCKER_SHARE_BASH_FUNCTIONS="-v C:/Users/tlacuache/pcloud/config/bash/functions:/etc/bash.bash_functions:ro,Z"
    export DOCKER_SHARE_GIT_CONFIG="-v C:/Users/tlacuache/pcloud/config/git/gitconfig:/etc/gitconfig:ro,Z"
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
fi
