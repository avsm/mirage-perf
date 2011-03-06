#!/bin/bash -ex
# Performance tests for blk read/writes

ROOTDIR=`pwd`

function xen_direct {
  cd $ROOTDIR/app
  sudo xl destroy blk || true
  # compile
  mir-xen block.xen
  sudo dd if=/dev/zero of=/root/testvbd count=20 bs=1M
  # spawn VM
  cp ../minios-config _build
  cd _build
  sudo xl create minios-config &
  sleep 2
 # (
 #  sleep 7;
 #  sudo xl destroy blk;
 # ) &
  sudo xl console blk
}

xen_direct
