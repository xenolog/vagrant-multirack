#!/bin/bash

if [[ "x${DEBUG}" != "x" ]] ; then
  set -x
fi

HOSTNAME=`hostname`
USAGE="Usage: $0 {start|stop}";

RACK_NO=`printf "%02d" $RACK_NO`
if [[ "${RACK_NO}" == "00" ]] ; then
  echo 'RACK_NO undefined, please define it as integer 1..253'
  exit 1
fi

etcd_fetch_data() {
  PHY_IF=`etcdctl get "/network_metadata/racks/${RACK_NO_SHORT}/phy_if"`
  PHY_NET=`etcdctl get "/network_metadata/racks/${RACK_NO_SHORT}/subnet"`
  PHY_IP=`echo ${PHY_NET} | awk -F. '{print $1"."$2"."$3"."254}'`
  PHY_MASKLEN=`echo ${PHY_NET} | awk -F'/' '{print $2}'`
  OUT_IF='eth0'
}

router_start() {
  if [[ "${SYSTEMD}" != "1" ]] ; then
    echo "The better way to start TOR virtual router is a 'systemctl start tar@{RACK_NO}' call."
  fi

  etcd_fetch_data
  # setup rack's interfaces
  ip a add "${PHY_IP}/${PHY_MASKLEN}" dev $PHY_IF
  ip l set up $PHY_IF

  # NAT all traffic to external world from this rack
  iptables -t nat -A POSTROUTING -s ${PHY_NET} --out-interface ${OUT_IF} -j MASQUERADE

  # Accept FORWARD for any traffic
  iptables -P FORWARD ACCEPT
}

router_stop() {
  etcd_fetch_data
  # remove NAT for traffic to external world from this rack
  iptables -t nat -D POSTROUTING -s ${PHY_NET} --out-interface ${OUT_IF} -j MASQUERADE

  ip a flush dev $PHY_IF
  ip l set down $PHY_IF
}

# main

if [[ $# -ne 1 ]]; then
    echo $USAGE
    exit 1
fi

case $1 in
    start) router_start
    ;;

    stop) router_stop
    ;;

    *) usage; exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac
