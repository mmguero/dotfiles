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

if [ $MACOS ]; then
  export VAGRANT_DEFAULT_PROVIDER=vmware_fusion
else
  export VAGRANT_DEFAULT_PROVIDER=virtualbox
fi

# update all outdated vagrant boxes
function vbu() {
  vagrant box outdated --global | grep "is outdated" | cols 2 | xargs -r -l vagrant box update --box
}