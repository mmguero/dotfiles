#!/bin/bash

bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

brew install bash
grep /opt/homebrew/bin/bash /etc/shells || (echo '/opt/homebrew/bin/bash' | sudo tee -a /etc/shells)

# Add the following line to your ~/.bash_profile:
#  [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"
brew install bash-completion

brew install zeek

# Commands also provided by macOS have been installed with the prefix "g".
# If you need to use these commands with their normal names, you
# can add a "gnubin" directory to your PATH from your bashrc like:
#   PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
brew install coreutils

brew install diffutils
brew install dos2unix

# All commands have been installed with the prefix "g".
# If you need to use these commands with their normal names, you
# can add a "gnubin" directory to your PATH from your bashrc like:
#   PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
brew install findutils

brew install gawk
brew install git

# GNU "indent" has been installed as "gindent".
# If you need to use it as "indent", you can add a "gnubin" directory
# to your PATH from your bashrc like:
#     PATH="/opt/homebrew/opt/gnu-indent/libexec/gnubin:$PATH"
brew install gnu-indent

# GNU "sed" has been installed as "gsed".
# If you need to use it as "sed", you can add a "gnubin" directory
# to your PATH from your bashrc like:
#     PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
brew install gnu-sed

# GNU "tar" has been installed as "gtar".
# If you need to use it as "tar", you can add a "gnubin" directory
# to your PATH from your bashrc like:
#     PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"
brew install gnu-tar

# GNU "which" has been installed as "gwhich".
# If you need to use it as "which", you can add a "gnubin" directory
# to your PATH from your bashrc like:
#     PATH="/opt/homebrew/opt/gnu-which/libexec/gnubin:$PATH"
brew install gnu-which

brew install gnutls

# All commands have been installed with the prefix "g".
# If you need to use these commands with their normal names, you
# can add a "gnubin" directory to your PATH from your bashrc like:
#   PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
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
brew install tree
brew install unrar
brew install vim
brew install watch
brew install wdiff
brew install wget
brew install zoxide

brew install neilotoole/sq/sq

brew tap homebrew/cask-versions
brew tap homebrew/cask-fonts

# brew cask install docker-edge
brew install --cask diskwave
brew install --cask firefox
brew install --cask homebrew/cask-fonts/font-hack
brew install --cask iterm2
brew install --cask keepassxc
brew install --cask libreoffice
brew install --cask osxfuse
brew install --cask sublime-text
brew install --cask veracrypt
brew install --cask wireshark
