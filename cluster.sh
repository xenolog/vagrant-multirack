#!/bin/bash

COMMAND=$1
if [[ "${COMMAND}" == "create" ]] ; then
    echo "Cluster will be created."
    vagrant up
    rc=$?
    if [[ "${rc}" == "0" ]] && [[ -z "${VAGRANT_MR_NO_PROVISION}" ]]; then
      echo "Provisioning started:"
      ANSIBLE_FORCE_COLOR=true ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s' ansible-playbook --timeout=30 --inventory-file=.vagrant/provisioners/ansible/inventory --become -v playbooks/cluster.yaml
      rc=$?
      echo "Provisioning done, rc=${rc}"
    fi
    exit $rc
elif [[ "${COMMAND}" == "destroy" ]] ; then
    vagrant destroy -f
    exit $?
else
    echo "[err] unsupported command."
    exit 1
fi