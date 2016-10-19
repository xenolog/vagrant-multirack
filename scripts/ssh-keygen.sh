#!/bin/bash
mkdir -p tmp/ssh
if ! [ -f tmp/ssh/id_rsa ] ; then
  ssh-keygen -N '' -t rsa -f tmp/ssh/id_rsa && cp tmp/ssh/id_rsa.pub tmp/ssh/authorized_keys
  if [ -f ~/.ssh/id_rsa.pub ] ; then
    cat ~/.ssh/id_rsa.pub >> tmp/ssh/authorized_keys
  fi
fi
