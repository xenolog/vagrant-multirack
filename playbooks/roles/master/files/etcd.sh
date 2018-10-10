#!/bin/bash

if [[ "z${DEBUG}" != "z" ]] ; then
  set -x
fi

HOSTNAME=`hostname`
USAGE="Usage: $0 {start|stop|backup}";

etcd_fetch_data() {
  CONTAINER_NAME="${CONTAINER_NAME:-etcd.service}"
  ETCD_IPV4=${ETCD_IPV4}
  ETCD_BACKUP="/var/lib/etcd/backup.yaml"
  if [[ -z ${ETCD_IPV4} ]] ; then
    echo "No IP address for ETCD endpoint given. Echo ETCD_IPV4 is empty."
    exit 1
  fi
  if [[ -z ${SYSTEMD} ]] ; then
    RUNMODE='-d'
  else
    # for using under systemd we should not exit when server started
    RUNMODE=''
  fi
}

etcd_start() {
  etcd_fetch_data

  if [[ ! -z $(docker ps | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    echo "container with ETCD already running."
    exit 1
  fi

  mkdir -p /var/lib/etcd

  if [[ ! -z $(docker ps --all | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    /usr/bin/docker rm ${CONTAINER_NAME} 2>&1 > /dev/null
  fi
  /usr/bin/docker run ${RUNMODE} -p 2379:2379 -p 2380:2380 -p 4001:4001 --name ${CONTAINER_NAME} \
    -v /usr/share/ca-certificates/:/etc/ssl/certs quay.io/coreos/etcd:latest \
    etcd -name etcd0 -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 -listen-peer-urls http://0.0.0.0:2380 \
    -advertise-client-urls http://${ETCD_IPV4}:2379,http://${ETCD_IPV4}:4001
  # this is a last line of start(), because systemd simple unit type used
}

etcd_post_start() {
  etcd_fetch_data

  sleep 1
  if [[ -z $(docker ps | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    echo "container with ETCD does not running."
    exit 1
  fi

  if [[ -f ${ETCD_BACKUP} ]] ; then
    etcdtool -p http://127.0.0.1:4001 import -y -f yaml / ${ETCD_BACKUP}
  fi
}

etcd_backup() {
  etcd_fetch_data
  mkdir -p /var/lib/etcd
  etcdtool -p http://127.0.0.1:4001 export -f yaml / > ${ETCD_BACKUP}
}

etcd_stop() {
  etcd_fetch_data

  if [[ ! -z $(docker ps | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    # backup of etcd data should be only if etcd is running
    etcd_backup
    /usr/bin/docker kill ${CONTAINER_NAME} 2>&1 > /dev/null
  fi

  if [[ ! -z $(docker ps --all | grep " ${CONTAINER_NAME}" | awk '{print $1}') ]] ; then
    sleep 1
    /usr/bin/docker rm ${CONTAINER_NAME} 2>&1 > /dev/null
  fi
}

etcd_post_stop() {
  true
}

# main

if [[ $# -ne 1 ]]; then
    echo $USAGE
    exit 1
fi

case $1 in
    start) etcd_start
    ;;

    post-start) etcd_post_start
    ;;

    stop) etcd_stop
    ;;

    post-stop) etcd_post_stop
    ;;

    backup) etcd_backup
    ;;

    *) usage; exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac

