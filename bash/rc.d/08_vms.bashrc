# virtualization

########################################################################
# kvm/qemu/libvirt
########################################################################
export LIBVIRT_DEFAULT_URI='qemu:///system'
alias vs='virsh'
alias vls='virsh list --all'
alias vt='virter'
alias vti='virter image'
alias vtv='virter vm'
alias vv='virter vm'

########################################################################
# vagrant
########################################################################
if [[ $LINUX ]]; then
  function vagrantd() {
    ENGINE=${CONTAINER_ENGINE:-podman}
    if [[ "$ENGINE" == "podman" ]]; then
      MOUNT_HOME="${VAGRANT_HOME:-$HOME/.vagrant.d}"
      mkdir -p "$MOUNT_HOME"/{boxes,data,tmp}
      $ENGINE run -it --rm \
        -e LIBVIRT_DEFAULT_URI \
        -e IGNORE_RUN_AS_ROOT=1 \
        -e VAGRANT_DEFAULT_PROVIDER=libvirt \
        -v /var/run/libvirt/:/var/run/libvirt/ \
        -v "$MOUNT_HOME"/boxes:/.vagrant.d/boxes \
        -v "$MOUNT_HOME"/data:/.vagrant.d/data \
        -v "$MOUNT_HOME"/tmp:/.vagrant.d/tmp \
        -v "$(realpath "${PWD}")":"${PWD}" \
        -w "${PWD}" \
        $CONTAINER_SHARE_TMP \
        --network host \
        --pull=never \
        --entrypoint /bin/bash \
        --security-opt label=disable \
        oci.guero.org/vagrant-libvirt:latest \
        /usr/bin/vagrant "$@"
    else
      $ENGINE run -it --rm \
        -e LIBVIRT_DEFAULT_URI \
        -e USER_UID=$(id -u) \
        -e USER_GID=$(id -g) \
        -e VAGRANT_DEFAULT_PROVIDER=libvirt \
        -v /var/run/libvirt/:/var/run/libvirt/ \
        -v "${VAGRANT_HOME:-$HOME/.vagrant.d}":/.vagrant.d \
        -v "$(realpath "${PWD}")":"${PWD}" \
        -w "${PWD}" \
        $CONTAINER_SHARE_TMP \
        --network host \
        --pull=never \
        oci.guero.org/vagrant-libvirt:latest \
        /usr/bin/vagrant "$@"
    fi
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
  function vbud() {
    vagrantd box outdated --global | grep "is outdated" | cols 2 | xargs -r -l vagrantd box update --box
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
  function vbu() {
    vagrant box outdated --global | grep "is outdated" | cols 2 | xargs -r -l vagrant box update --box
  }
  function vbak() {
    while read BOX_INFO; do
      BOX_NAME="$(echo "${BOX_INFO}" | cut -d " " -f 1)"
      BOX_PROVIDER="$(echo "${BOX_INFO}" | cut -d " " -f 2)"
      BOX_VERSION="$(echo "${BOX_INFO}" | cut -d " " -f 3)"
      FN="$(echo "${BOX_NAME}"_"${BOX_PROVIDER}"_"${BOX_VERSION}" | tr -c "[:alnum:]." "_" | sed "s/_*$/.box/")"
      echo "Repackaging ${BOX_NAME} (${BOX_PROVIDER}, ${BOX_VERSION}) to ${FN}..."
      vagrant box repackage "$BOX_NAME" "$BOX_PROVIDER" "$BOX_VERSION" && \
        mv -v package.box "$FN" || \
        echo "Failed to repackage ${BOX_NAME} (${BOX_PROVIDER}, ${BOX_VERSION})"
    done <<<$(vagrant box list --no-tty --no-color | tr -d ',()' | tr -s ' ' | tr -s '\n' )
  }

  function vvrun() {
    MEMGB="$(numfmt --to iec --format "%8f" $(echo ${QEMU_RAM:-4096}*1024*1024 | bc) | sed "s/\.0G$/GiB/")"
    IMG="${QEMU_IMG:-debian-12}"
    ID=$((120 + $RANDOM % 80))
    [[ "${QEMU_ARCH:-amd64}" == "amd64" ]] && IMG_SUFFIX= || IMG_SUFFIX="-${QEMU_ARCH}"

    IMG_USER="${QEMU_USER:-}"
    if [[ -z "${IMG_USER}" ]]; then
      case "${IMG}" in
        alma-* )         IMG_USER=almalinux ;;
        amazonlinux-* )  IMG_USER=ec2-user ;;
        centos-* )       IMG_USER=centos ;;
        debian-* )       IMG_USER=debian ;;
        fedora-* )       IMG_USER=fedora ;;
        rocky-* )        IMG_USER=rocky ;;
        ubuntu-* )       IMG_USER=ubuntu ;;
        * )              IMG_USER=root ;;
      esac
    fi
    virter vm run "${IMG}${IMG_SUFFIX}" \
      --id ${ID} \
      --name "${IMG}-${ID}" \
      --arch "${QEMU_ARCH:-amd64}" \
      --vcpus ${QEMU_CPU:-2} \
      --memory ${MEMGB} \
      --bootcapacity ${QEMU_DISK:-40G} \
      --mount "host=$(pwd),vm=/host" \
      --user "${IMG_USER}" \
      --wait-ssh \
      --container-pull-policy Never \
      "$@"
    virter vm ssh "${IMG}-${ID}"
    unset CONFIRMATION
    read -p "Remove VM ${IMG}-${ID} [y/N]? " CONFIRMATION
    CONFIRMATION=${CONFIRMATION:-N}
    if [[ $CONFIRMATION =~ ^[Yy] ]]; then
      virter vm rm "${IMG}-${ID}"
    fi
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

command -v vagrant >/dev/null 2>&1 && VAGRANT_PLUGINS="$(vagrant plugin list 2>/dev/null)" || VAGRANT_PLUGINS=
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
    VNC_PORT=$(unusedport)
    VNC_ID=$((VNC_PORT-5900))
    nohup qemu-system-x86_64 \
        -machine "$MACHINE" \
        -smp ${QEMU_CPU:-2} \
        -boot d \
        -cdrom "$1" \
        -m ${QEMU_RAM:-4096} \
        -vga virtio \
        -usb \
        -device usb-tablet \
        -vnc :$VNC_ID >/dev/null 2>&1 </dev/null &
    sleep 1
    echo "Connecting to vnc://localhost:$VNC_PORT" >&2
    o vnc://localhost:$VNC_PORT >/dev/null 2>&1
  else
    echo "No image file specified" >&2
    exit 1
  fi
}

# run a fake machine
function fm() {
  fakemachine \
      -c ${QEMU_CPU:-2} \
      -m ${QEMU_RAM:-4096} \
      -s ${QEMU_DISK:-50G} \
      "$@"
}