#!/bin/bash -ex
# Performance tests for DNS

ROOTDIR=`pwd`

# Socket backend

function unix_direct {
  cd $ROOTDIR/app
  # compile
  mir-unix-direct sleep.bin
  # spawn server process
  sudo ./_build/sleep.bin &
  serverpid=$!
  sleep 20
  sudo kill $serverpid
}

function xen_direct {
  cd $ROOTDIR/app
  sudo xl destroy sleep || true
  # compile
  mir-xen sleep.xen
  # spawn VM
  cp ../minios-config _build
  cd _build
  sudo xl create minios-config &
  sleep 1
  domid=`sudo xl domid sleep`
  (
   sleep 20;
   sudo xl destroy sleep;
  ) &
  sudo xl console sleep
}

#unix_direct
xen_direct
