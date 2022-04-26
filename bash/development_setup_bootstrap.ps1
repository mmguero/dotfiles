# download the scoop installer
iwr -useb get.scoop.sh -outfile 'install_scoop.ps1'

# add -RunAsAdmin if you *must* run as Administrator
.\install_scoop.ps1

# remove the scoop installer
Remove-Item .\install_scoop.ps1

# bootstrap bare minimum (let development_setup.sh do the rest)
scoop install main/git main/curl main/grep main/less main/sed main/touch main/msys2
