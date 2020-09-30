#!/bin/bash -eux
#
# This is a non-interactive script for the automated setup of a Canonical MAAS KVM development environment

# environment variables
source .env

# check kvm
kvm-ok

# fetch latest bionic image if it does not exist locally
[[ -f $(basename ${IMAGE_URL}) ]] || curl -O ${IMAGE_URL}

# create an image based on cloud-init image 100G in size
qemu-img create -b $(basename ${IMAGE_URL}) -f qcow2 -F qcow2 ${MAAS_HOSTNAME}-bionic-server-cloudimg.qcow2 100G

# ssh keypair
ssh-keygen -f id_rsa -N '' -C "ubuntu@${MAAS_HOSTNAME}.${MAAS_DOMAIN} - $(date +%s)"
SSH_PUBKEY=$(cat id_rsa.pub)

# generate clout_init.cfg
cat .env user-data.sh > user-data.tmp
USER_DATA=$(base64 -w 0 user-data.tmp)
cat << EOF >cloud_init.cfg
#cloud-config
hostname: ${MAAS_HOSTNAME}
fqdn: ${MAAS_HOSTNAME}.maas
manage_etc_hosts: true
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/ubuntu
    shell: /bin/bash
    lock_passwd: false
    ssh-authorized-keys:
      - ${SSH_PUBKEY}
chpasswd:
  list: |
    ubuntu:ubuntu
  expire: False
write_files:
  - encoding: b64
    content: ${USER_DATA}
    owner: root:root
    path: /root/user-data.sh
    permissions: '0700'
runcmd:
  - [ sh, -c, '/root/user-data.sh' ]
EOF

# generate network.cfg
cat << EOF > network.cfg
version: 2
ethernets:
  enp1s0:
    dhcp4: false
    dhcp6: false
  enp2s0:
    dhcp4: true
    dhcp6: false
EOF

# generate local datasource
cloud-localds --network-config=network.cfg cloud-init.qcow2 cloud_init.cfg

# create VM
virt-install \
  --boot hd \
  --console pty,target_type=serial \
  --cpu host \
  --disk path=${MAAS_HOSTNAME}-bionic-server-cloudimg.qcow2,device=disk \
  --disk path=cloud-init.qcow2,device=cdrom \
  --graphics vnc \
  --hvm \
  --memory ${MEMORY} \
  --name ${MAAS_HOSTNAME} \
  --network network:maas \
  --network network:default \
  --noautoconsole \
  --os-type Linux \
  --os-variant ubuntu18.04 \
  --vcpus ${VCPUS} \
  --virt-type kvm 

# clean up
rm -f cloud_init.cfg network.cfg user-data.tmp
