#!/bin/bash -ux

# environment variables
source .env

# stop VM
virsh destroy ${MAAS_HOSTNAME}
virsh undefine --remove-all-storage ${MAAS_HOSTNAME}

# clean directory
rm -f id_rsa id_rsa.pub cloud_init.cfg network.cfg user-data.tmp *.qcow2
