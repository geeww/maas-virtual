# Virtual MAAS VM development environment

- [Virtual MAAS VM development environment](#virtual-maas-vm-development-environment)
  - [Preface](#preface)
  - [Configuration](#configuration)
  - [Networking](#networking)
    - [Default libvirt network](#default-libvirt-network)
    - [Nested VM NAT](#nested-vm-nat)
  - [Creating the environment](#creating-the-environment)
  - [Restarting the environment](#restarting-the-environment)
  - [Logging in](#logging-in)
    - [virsh console](#virsh-console)
    - [SSH](#ssh)
  - [MAAS CLI](#maas-cli)
  - [MAAS UI](#maas-ui)
  - [Destroying and cleaning the environment](#destroying-and-cleaning-the-environment)
  - [Libvirt snapshots](#libvirt-snapshots)
  - [Troubleshooting](#troubleshooting)
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
This project assumes that libvirt is installed and the default network exists, that provides DHCP and NAT for MAAS and nested VMs to access the internet

### Nested VM NAT
Nested VMs will access the internet via NAT, via the `maas` network defined on the MAAS server

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
ssh -i id_rsa ubuntu@${MAAS_NAT_IP} sudo maas ${PROFILE} help
```

## MAAS UI
Install a web browser on the MAAS VM (Firefox in this case) and open `http://${MAAS_IP}:5240`
```
MAAS_NAT_IP=$(virsh domifaddr --domain ${MAAS_HOSTNAME} | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
ssh -i id_rsa ubuntu@${MAAS_NAT_IP} "sudo apt-get -y install firefox; \
  firefox http://${MAAS_IP}:5240"
```
Use the `USERNAME` and `PASSWORD` from the environment `.env` file to login

## Destroying and cleaning the environment
Remove MAAS and nested VMs, ssh keys and qcow files
```
./maas-virtual-clean.sh
```

## Libvirt snapshots
libvirt can be utilized for snapshots to save rebuilding from scratch each time a pristine MAAS environment is required
```
# create a snapshot
virsh snapshot-create --domain ${MAAS_HOSTNAME}

# restore snapshot
virsh snapshot-revert maas-dev --current

# delete current snapshot
virsh snapshot-delete --domain ${MAAS_HOSTNAME} --current
```

## Troubleshooting
- MAAS VM and nested VM crash during deployment?
  Check if huge pages are enabled and try disabling them on the bare metal host

## Links
- http://maas.io/
- https://maas.io/docs/advanced-cli-tasks
- https://maas.io/docs/composable-hardware
- https://discourse.maas.io/t/setting-up-a-flexible-virtual-maas-test-environment/142
