# disable ipv6
echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.d/99-hardening.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.d/99-hardening.conf

# enable ip fowarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# activate
sysctl --system

# disable motd
systemctl stop motd-news.service motd-news.timer
systemctl disable motd-news.timer

# install packages
DEBIAN_FRONTEND=noninteractive
apt update
apt -y install qemu-guest-agent jq

# enable NAT
iptables -t nat -A POSTROUTING -o enp2s0 -j MASQUERADE

# configure debconf to autosave iptables rules and install iptables-persistent 
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt -y install iptables-persistent

# KVM
apt -y install qemu-kvm libvirt-bin virt-manager
## enable insecure tcp listener
sed -i 's/#libvirtd_opts=""/libvirtd_opts="-l"/' /etc/default/libvirtd
sed -i 's/#listen_tcp = 1/listen_tcp = 1/g' /etc/libvirt/libvirtd.conf
sed -i 's/#listen_tls = 0/listen_tls = 0/g' /etc/libvirt/libvirtd.conf
sed -i 's/#auth_tcp = "sasl"/auth_tcp = "none"/g' /etc/libvirt/libvirtd.conf
systemctl restart libvirtd

# configure KVM MAAS network for guests
cat << EOF > maas.xml
<network>
  <name>maas</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <dns enable='no'/>
  <bridge name='virbr1' stp='off' delay='0'/>
  <domain name='${MAAS_DOMAIN}'/>
  <ip address='${MAAS_IP}' netmask='255.255.255.0'>
  </ip>
</network>
EOF
virsh net-define maas.xml
rm maas.xml
virsh net-start maas
virsh net-autostart maas

# configure MAAS default storage pool
virsh pool-define-as default dir - - - - "/var/lib/libvirt/images"  
virsh pool-autostart default  
virsh pool-start default

# install and configure postgres for MAAS
apt -y install postgresql
sudo --user postgres psql -c "CREATE USER \"$MAAS_DBUSER\" WITH ENCRYPTED PASSWORD '$MAAS_DBPASS'"
sudo --user postgres createdb -O "$MAAS_DBUSER" "$MAAS_DBNAME"
echo "host    $MAAS_DBNAME    $MAAS_DBUSER    0/0     md5" >> /etc/postgresql/10/main/pg_hba.conf

# install MAAS
snap install maas --channel=${MAAS_VERSION}

# init MAAS
echo "http://${MAAS_HOSTNAME}.${MAAS_DOMAIN}:5240/MAAS" | maas init region+rack --database-uri "postgres://$MAAS_DBUSER:$MAAS_DBPASS@localhost/$MAAS_DBNAME"

# create MAAS admin user
maas createadmin --username ${USERNAME} --password ${PASSWORD} --email ${EMAIL}
APIKEY=$(maas apikey --generate --username ${USERNAME})
# wait a few seconds, sometimes the next command fails otherwise
sleep 5

# login to MAAS for root user
maas login ${PROFILE} http://${MAAS_HOSTNAME}.${MAAS_DOMAIN}:5240/MAAS/api/2.0/ ${APIKEY}

# admin user sshkey
maas ${PROFILE} sshkeys create "key=$(cat /home/ubuntu/.ssh/authorized_keys)"

# configure maas settings
maas ${PROFILE} maas set-config name=upstream_dns value=${DNS_SERVER}

# determine networking id information
SUBNET_ID=$(maas ${PROFILE} subnet read ${MAAS_SUBNET} | jq .id)
FABRIC_ID=$(maas ${PROFILE} subnet read ${MAAS_SUBNET} | jq .vlan.fabric_id)
VLAN_ID=$(maas ${PROFILE} subnet read ${MAAS_SUBNET} | jq .vlan.vid)

# configure DHCP pool for 
maas ${PROFILE} ipranges create start_ip=${DHCP_START} end_ip=${DHCP_END} subnet=${SUBNET_ID} type=dynamic

# vlans
maas ${PROFILE} vlan update ${FABRIC_ID} ${VLAN_ID} primary_rack=${MAAS_HOSTNAME} dhcp_on=True 

# subnets
maas ${PROFILE} subnet update ${SUBNET_ID} gateway_ip=${MAAS_IP} dns_servers=${MAAS_IP} active_discovery=true

## select focal for import (bionic is automatically selected)
maas ${PROFILE} boot-source-selections create 1 os="ubuntu" release="focal" arches="amd64"  subarches="*" labels="*"

# images import
maas ${PROFILE} boot-resources import

# wait for images import
echo 'waiting for boot-resources import...'
while [ $(maas ${PROFILE} boot-resources is-importing | tail -1) == 'true' ]; do 
  sleep 5
done

# rack controller sync
SYSTEM_ID=$(maas ${PROFILE} rack-controllers read | jq -r .[].system_id)

# wait for rack controller sync
echo 'waiting for rack-controllers sync...'
while [ $(maas ${PROFILE} rack-controller list-boot-images ${SYSTEM_ID} | jq -r .status) != 'synced' ]; do 
  sleep 5
done

# configure MAAS KVM host
maas ${PROFILE} vm-hosts create type=virsh name=${MAAS_HOSTNAME} power_address=qemu+tcp://${MAAS_IP}/system

# refresh MAAS KVM host info
maas ${PROFILE} vm-host refresh 1

# shutdown when successful
shutdown now