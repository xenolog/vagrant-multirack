#!/bin/bash

node_name_prefix="vagrant-multirack_${USER}"
if [[ "${VAGRANT_MR_NAME_SUFFIX}" != "" ]] ; then
    node_name_prefix="${node_name_prefix}-${VAGRANT_MR_NAME_SUFFIX}"
fi

VMs=$(virsh list --all | grep "${node_name_prefix}" | awk '{print $2}' | sort)

if [[ "${VMs}" == "" ]] ; then
    echo "No VMs created for you env"
    exit 1
fi

SS=""
for i in $VMs ; do SS="${SS} $(virsh snapshot-list ${i} | grep -v -e ' Name ' -e '---------' | awk '{print $1}')"; done

echo $SS | perl -pe 's/\s+/\n/g' | sort | uniq

exit 0