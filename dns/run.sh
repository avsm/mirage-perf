#!/bin/bash -ex
# Performance tests for DNS

ROOTDIR=`pwd`

# Socket backend

function unix_socket {
  cd $ROOTDIR/app
  # compile
  mir-unix-socket deens.bin
  # spawn server process
  sudo ./_build/deens.bin &
  sleep 1
  serverpid=$!
  # short run to get the binary hot
  ../queryperf -l 2 < ../simple_data
  # then the recorded run
  ../queryperf -l 5 < ../simple_data > ../socket.log
  sudo kill $serverpid
}

function unix_direct {
  cd $ROOTDIR/app
  # compile
  mir-unix-direct deens.bin
  # spawn server process
  sudo ./_build/deens.bin &
  sleep 2
  serverpid=$!
  # short run to get the binary hot
  ../queryperf -l 2 -s 10.0.0.2 < ../simple_data
  # then the recorded run
  ../queryperf -l 5 -s 10.0.0.2 < ../simple_data > ../direct.log
  sudo kill $serverpid
}

function xen_direct {
  cd $ROOTDIR/app
  # compile
  mir-xen deens.xen
  # set up bridge
  sudo brctl addbr perf0 || true
  sudo brctl setfd perf0 0
  sudo brctl sethello perf0 0
  sudo brctl stp perf0 off
  sudo ifconfig perf0 10.0.0.1 netmask 255.255.255.0
  sudo ifconfig perf0 up
  # spawn VM
  cp ../minios-config _build
  cd _build
  sudo xl create minios-config &
  sleep 5
  ping -c 3 10.0.0.2
  (../../queryperf -l 5 -s 10.0.0.2 < ../../simple_data > ../../xen.log;
   sleep 3;
   sudo xl destroy deens;
   sudo ifconfig perf0 down;
   sudo brctl delbr perf0) &
  sudo xl console deens
}

unix_socket
#unix_direct
#xen_direct
