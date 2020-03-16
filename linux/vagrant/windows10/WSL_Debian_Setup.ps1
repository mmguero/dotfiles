Start-Process "debian.exe" -ArgumentList "install --root" -Wait
Start-Process "debian.exe" -ArgumentList 'run adduser vagrant --gecos ",,,," --disabled-password' -Wait
Start-Process "debian.exe" -ArgumentList "run echo 'vagrant:vagrant' | sudo chpasswd" -Wait
Start-Process "debian.exe" -ArgumentList "run usermod -aG sudo vagrant" -Wait
Start-Process "debian.exe" -ArgumentList "config --default-user vagrant" -Wait

