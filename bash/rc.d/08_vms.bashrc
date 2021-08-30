#vmware/vbox/kvm/qemu
alias vs='virsh -c qemu:///system '
alias qemuls='virsh -c qemu:///system list --all'
alias vag='vagrant'
alias vup='vagrant up'
alias vhalt='vagrant halt'
alias vrm='vagrant destroy'
alias vbl='vagrant box list'
alias vgs='vagrant global-status'
alias vsh='vagrant ssh'

########################################################################
# vagrant
########################################################################
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