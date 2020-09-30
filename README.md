# Virtual MAAS VM development environment

- [Virtual MAAS VM development environment](#virtual-maas-vm-development-environment)
  - [Preface](#preface)
  - [Configuration](#configuration)
  - [Networking](#networking)
    - [Default libvirt network](#default-libvirt-network)
    - [MAAS network](#maas-network)
  - [Creating the environment](#creating-the-environment)
  - [Restarting the environment](#restarting-the-environment)
  - [Logging in](#logging-in)
    - [virsh console](#virsh-console)
    - [SSH](#ssh)
  - [MAAS CLI](#maas-cli)
  - [Destroying and cleaning the environment](#destroying-and-cleaning-the-environment)
  - [Links](#links)

## Preface
This project creates a virtualized MAAS KVM development environment and is also suitable for adaptation to use in CI (MAAS changes/upgrades/IAC/etc).

Nested virtualization enables further VMs to be created by MAAS on the VM running MAAS.

It is tested and developed on an Ubuntu 20.04 desktop class machine and likely works fine on 18.04.

## Configuration
Configurables are located in the `.env` file

`source .env` before continuing

## Networking 
### Default libvirt network
This project assumes that libvirt is installed and the default network exists, that provides DHCP and NAT for MAAS and nested VMs to access the internet. The second interface of the MAAS KVM host will be attached to it.

### MAAS network
A MAAS-compatible network must exist on the bare-metal host. MAAS will manage this network.

To create this network
```
source .env
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
  <ip address='${KVM_ROUTER_IP}' netmask='255.255.255.0'>
  </ip>
</network>
EOF
virsh net-define maas.xml
rm maas.xml
virsh net-start maas
virsh net-autostart maas
```

## Creating the environment
After `source`ing the environment variables in `.env`

Then run
```
./maas-virtual.sh
```

The VM will shutdown when cloud-init finishes successfully.

Connect to the console to watch progress by 
```
virsh console ${MAAS_HOSTNAME}
```

## Restarting the environment
Restart the instance by
```
virsh start ${MAAS_HOSTNAME}
```

## Logging in
### virsh console
Login with username: `ubuntu`, password: `ubuntu`
```
virsh console ${MAAS_HOSTNAME}
```

### SSH
SSH to the IP of the NAT interface of the MAAS VM. The IP can be obtained using `virsh domifaddr`
```
MAAS_NAT_IP=$(virsh domifaddr --domain ${MAAS_HOSTNAME} | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
ssh -i id_rsa ubuntu@${MAAS_NAT_IP}
```

## MAAS CLI
The root user is automatically logged in to MAAS
```
MAAS_NAT_IP=$(virsh domifaddr --domain ${MAAS_HOSTNAME} | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
ssh -i id_rsa ubuntu@${MAAS_NAT_IP} sudo maas ${MAAS_HOSTNAME} help
```

## Destroying and cleaning the environment
Remove MAAS and nested VMs, ssh keys and qcow files
```
./maas-virtual-clean.sh
```

## Links
- http://maas.io/
- https://maas.io/docs/advanced-cli-tasks
- https://maas.io/docs/composable-hardware
- https://discourse.maas.io/t/setting-up-a-flexible-virtual-maas-test-environment/142

