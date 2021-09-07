# virtualization

########################################################################
# kvm/qemu/libvirt
########################################################################
export LIBVIRT_DEFAULT_URI='qemu:///system'
alias vs='virsh'
alias qemuls='virsh list --all'

########################################################################
# vagrant
########################################################################
alias vag='vagrant'
alias vup='vagrant up'
alias vhalt='vagrant halt'
alias vrm='vagrant destroy'
alias vbl='vagrant box list'
alias vgs='vagrant global-status'
alias vsh='vagrant ssh'
alias vplsr='gem list --remote vagrant-'
alias vpls='vagrant plugin list'

if [[ $LINUX ]]; then
  alias vagrantd='
    docker run -it --rm \
      -e LIBVIRT_DEFAULT_URI \
      -v /var/run/libvirt/:/var/run/libvirt/ \
      -v ~/.vagrant.d:/.vagrant.d \
      -v $(realpath "${PWD}"):${PWD} \
      -w $(realpath "${PWD}") \
      --network host \
      ghcr.io/mmguero/vagrant-libvirt:latest \
      vagrant'
  alias vagd='vagrantd'
  alias vupd='vagrantd up'
  alias vhaltd='vagrantd halt'
  alias vrmd='vagrantd destroy'
  alias vbld='vagrantd box list'
  alias vgsd='vagrantd global-status'
  alias vshd='vagrantd ssh'
  alias vplsd='vagrantd plugin list'
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