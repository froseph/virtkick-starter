#!/bin/sh
if ! [ -e .system-setup ];then
  # assure make
  if ! [ -e ~/.ssh/id_rsa_virtkick ];then
    ssh-keygen -q -N "" -f ~/.ssh/id_rsa_virtkick
    echo '
Host localhost
  User virtkick
  IdentityFile ~/.ssh/id_rsa_virtkick
  StrictHostKeyChecking no
    ' >> ~/.ssh/config
  fi
  echo 'I am about to create user "virtkick" in group "kvm" and add your public ssh key to allow passwordless login'
  sudo bash -c '
    if which apt-get &> /dev/null;then
      echo "Detected apt-get based system, trying to auto install required packages"
      (apt-get --fix-missing -y install git curl openssh-server qemu-kvm libvirt-bin python-pip python-libvirt python-libxml2 libxml2-dev libxslt-dev)
      sleep 1 # give some time for virtkick to start
    fi
  '

  # this makes no attempt to decide which port to use if multiple ports specified. so pick the first one.
  export SSH_PORT=$(sudo grep -oE "^\s*Port\s+[0-9]+" /etc/ssh/sshd_config|grep -oE "[0-9]+"|head -n 1)
  if [ "$SSH_PORT" == "" ];then
    export SSH_PORT="22"
  fi
  echo $SSH_PORT > .ssh-port

  sudo bash -c '
  if ! [ -e /var/run/libvirt/libvirt-sock ];then
    echo "Cannot find /var/run/libvirt/libvirt-sock, please install libvirt" && exit 1
  fi;
  export LIBVIRT_GROUP=$(stat -c "%G" /var/run/libvirt/libvirt-sock)
  if [ "$LIBVIRT_GROUP" != \"root\" ];then
    export ADD_LIBVIRT="-G $LIBVIRT_GROUP"
  fi && 
  if ! getent group kvm > /dev/null; then 
    echo "It seems KVM is not installed, no group kvm?" && exit 1
  fi &&
  if ! getent passwd virtkick > /dev/null; then 
    useradd virtkick -m -c "VirtKick orchestrator" -g kvm $ADD_LIBVIRT
  fi && 
  mkdir -p ~virtkick/{.ssh,hdd,iso} &&
  chown -R virtkick:kvm ~virtkick &&
  chmod 750 ~virtkick &&
  cat > ~virtkick/.ssh/authorized_keys' < ~/.ssh/id_rsa_virtkick.pub
  if ! ssh -p $SSH_PORT -o "StrictHostKeyChecking no" virtkick@localhost virsh list > /dev/null;then
    echo 'Cannot run "virsh list" on virtkick@localhost, libvirt is not setup properly!'
    echo 'virtkick user needs rights to read/write /var/run/libvirt/libvirt-sock'
    exit 1
	fi
  touch .system-setup
else
  export SSH_PORT="$(cat .ssh-port 2> /dev/null || echo 22)"
fi
