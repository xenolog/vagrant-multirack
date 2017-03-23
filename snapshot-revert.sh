#!/bin/bash

SNAPSHOT_NAME=$1
if [[ "${SNAPSHOT_NAME}" == "" ]] ; then
    echo "No snapshot name given"
    exit 1
fi

node_name_prefix="vagrant-multirack_${USER}"
if [[ "${VAGRANT_MR_NAME_SUFFIX}" != "" ]] ; then
    node_name_prefix="${node_name_prefix}-${VAGRANT_MR_NAME_SUFFIX}"
fi

VMs=$(virsh list --all | grep "${node_name_prefix}" | awk '{print $2}' | sort)

if [[ "${VMs}" == "" ]] ; then
    echo "No VMs created for you env"
    exit 1
fi

for i in $VMs ; do virsh suspend $i ; done
for i in $VMs ; do virsh snapshot-revert $i $SNAPSHOT_NAME ; done
for i in $VMs ; do virsh resume $i ; done

exit 0