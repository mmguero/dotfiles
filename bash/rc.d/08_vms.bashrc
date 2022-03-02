# virtualization

########################################################################
# kvm/qemu/libvirt
########################################################################
export LIBVIRT_DEFAULT_URI='qemu:///system'
alias vs='virsh'
alias vls='virsh list --all'

########################################################################
# vagrant
########################################################################
if [[ $LINUX ]]; then
  function vagrantd() {
    docker run -it --rm \
      -e LIBVIRT_DEFAULT_URI \
      -e USER_UID=$(id -u) \
      -e USER_GID=$(id -g) \
      -e VAGRANT_DEFAULT_PROVIDER=libvirt \
      -v /var/run/libvirt/:/var/run/libvirt/ \
      -v "${VAGRANT_HOME:-$HOME/.vagrant.d}":/.vagrant.d \
      -v "$(realpath "${PWD}")":"${PWD}" \
      -w "${PWD}" \
      --network host \
      --pull=never \
      ghcr.io/mmguero/vagrant-libvirt:latest \
      vagrant "$@"
  }
  function vagd() {
    vagrantd "$@"
  }
  function vupd() {
    vagrantd up "$@"
  }
  function vhaltd() {
    vagrantd halt "$@"
  }
  function vrmd() {
    vagrantd destroy "$@"
  }
  function vbld() {
    vagrantd box list "$@"
  }
  function vgsd() {
    vagrantd global-status "$@"
  }
  function vshd() {
    vagrantd ssh "$@"
  }
  function vplsd() {
    vagrantd plugin list "$@"
  }

  function vagrant() {
    if which vagrant >/dev/null 2>&1; then
      "$(which vagrant)" "$@"
    else
      vagrantd "$@"
    fi
  }
  function vag() {
    vagrant "$@"
  }
  function vup() {
    vagrant up "$@"
  }
  function vhalt() {
    vagrant halt "$@"
  }
  function vrm() {
    vagrant destroy "$@"
  }
  function vbl() {
    vagrant box list "$@"
  }
  function vgs() {
    vagrant global-status "$@"
  }
  function vsh() {
    vagrant ssh "$@"
  }
  function vpls() {
    vagrant plugin list "$@"
  }

else
  alias vag='vagrant'
  alias vup='vagrant up'
  alias vhalt='vagrant halt'
  alias vrm='vagrant destroy'
  alias vbl='vagrant box list'
  alias vgs='vagrant global-status'
  alias vsh='vagrant ssh'
  alias vplsr='gem list --remote vagrant-'
  alias vpls='vagrant plugin list'
fi

VAGRANT_PLUGINS="$(vagrant plugin list 2>/dev/null)"
if [[ $MACOS ]] && [[ "$VAGRANT_PLUGINS" == *"vmware"* ]]; then
  export VAGRANT_DEFAULT_PROVIDER=vmware_fusion
elif [[ "$VAGRANT_PLUGINS" == *"vagrant-libvirt"* ]]; then
  export VAGRANT_DEFAULT_PROVIDER=libvirt
elif [[ "$VAGRANT_PLUGINS" == *"vagrant-vmware"* ]]; then
  export VAGRANT_DEFAULT_PROVIDER=vagrant-vmware-desktop
elif [[ "$VAGRANT_PLUGINS" == *"vagrant-vbguest"* ]]; then
  export VAGRANT_DEFAULT_PROVIDER=virtualbox
else
  unset VAGRANT_DEFAULT_PROVIDER
fi

# update all outdated vagrant boxes
function vbu() {
  vagrant box outdated --global | grep "is outdated" | cols 2 | xargs -r -l vagrant box update --box
}

# boot an ISO in qemu
function qemuiso() {
  if [[ "$1" ]]; then
    if [[ $MACOS ]]; then
      MACHINE="type=q35,accel=hvf"
    elif [[ $LINUX ]] && dd if=/dev/kvm count=0 >/dev/null 2>&1; then
      MACHINE="type=q35,accel=kvm"
    else
      MACHINE="type=q35"
    fi
    nohup qemu-system-x86_64 \
        -machine "$MACHINE" \
        -smp ${QEMU_CPU:-2} \
        -boot d \
        -cdrom "$1" \
        -m ${QEMU_RAM:-4096} \
        -vga virtio \
        -usb \
        -device usb-tablet \
        -display default,show-cursor=on >/dev/null 2>&1 </dev/null &
    o vnc://localhost:5900
  else
    echo "No image file specified" >&2
    exit 1
  fi
}