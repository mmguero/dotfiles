Start-Process "wsl.exe" -ArgumentList "--set-default-version 1" -Wait
Start-Process "debian.exe" -ArgumentList "install --root" -Wait
Start-Process "debian.exe" -ArgumentList 'run adduser vagrant --gecos ",,,," --disabled-password' -Wait
Start-Process "debian.exe" -ArgumentList "run echo 'vagrant:vagrant' | sudo chpasswd" -Wait
Start-Process "debian.exe" -ArgumentList "run usermod -aG sudo vagrant" -Wait
Start-Process "debian.exe" -ArgumentList "run apt-get update && apt-get -y dist-upgrade && apt-get -y install curl git bc tmux" -Wait
Start-Process "debian.exe" -ArgumentList "config --default-user vagrant" -Wait
Start-Process "debian.exe" -ArgumentList "run mkdir -p ~/.config && git clone --recursive --depth 1 --single-branch -b master https://github.com/mmguero/config ~/.config/mmguero.config" -Wait
Start-Process "debian.exe" -ArgumentList "run rm -f ~/.bashrc && ln -s -r ~/.config/mmguero.config/bash/rc ~/.bashrc && ln -s -r ~/.config/mmguero.config/bash/aliases ~/.bash_aliases && ln -s -r ~/.config/mmguero.config/bash/functions ~/.bash_functions && ln -s -r ~/.config/mmguero.config/bash/rc.d ~/.bashrc.d && mkdir -p ~/.local/bin && ln -s -r ~/.config/mmguero.config/bash/context-color/context-color ~/.local/bin/ && ln -s -r ~/.config/mmguero.config/linux/tmux/tmux.conf ~/.tmux.conf && ln -s -r ~/.config/mmguero.config/git/gitconfig ~/.gitconfig" -Wait