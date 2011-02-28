#!/bin/bash -ex
# Performance tests for flood pings

ROOTDIR=`pwd`

# Socket backend

function unix_direct {
  cd $ROOTDIR/app
  # compile
  mir-unix-direct ping.bin
  # spawn server process
  sudo ./_build/ping.bin &
  serverpid=$!
  sleep 20
  sudo ping -c 20000 -f 10.0.0.2
  sudo kill $serverpid
}

function xen_direct {
  cd $ROOTDIR/app
  sudo xl destroy ping || true
  # compile
  mir-xen ping.xen
  # set up bridge
  sudo brctl addbr ping0 || true
  sudo brctl setfd ping0 0
  sudo brctl sethello ping0 0
  sudo brctl stp ping0 off
  sudo ifconfig ping0 10.0.0.1 netmask 255.255.255.0
  sudo ifconfig ping0 up
  # spawn VM
  cp ../minios-config _build
  cd _build
  sudo xl create minios-config &
  sleep 1
  ping -c 3 10.0.0.2
  domid=`sudo xl domid ping`
  sudo brctl addif ping0 vif${domid}.0 || true
  (
   sudo ping -c 20000 -f 10.0.0.2
   sudo xl destroy ping;
   sudo ifconfig ping0 down;
   sudo brctl delbr ping0
  ) &
  sudo xl console ping
}

#unix_direct
xen_direct
