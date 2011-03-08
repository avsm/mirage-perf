#!/bin/bash -ex
# Performance tests for DNS

sudo echo 'Ensuring we have sudo credentials... done!'
  
ROOTDIR=$(pwd)
SHORTRUN=2
LONGRUN=30
DEENSIP=10.0.0.2

compile () {
  cd $ROOTDIR/app
  mir-$1 deens.bin
  cd ..
}

do_run () {
  queryperf -l $(SHORTRUN) -s $(DEENSIP) < $1 
  queryperf -l $(LONGRUN) -s $(DEENSIP) < $1 > $2
}

unix_socket () {
  compile unix-socket
  
  sudo ./app/_build/deens.bin &
  sleep 1
  serverpid=$!
  
  # short run to get the binary hot
  queryperf -l 2 < data/simple_data
  # then the recorded run
  queryperf -l 5 < data/simple_data > data/socket.log
  
  sudo kill $serverpid
}

unix_direct () {
  compile unix-direct

  sudo ./app/_build/deens.bin &
  sleep 2
  serverpid=$!

  do_run data/simple_data data/direct.log

  # short run to get the binary hot
  queryperf -l 2 -s 10.0.0.2 < data/simple_data
  # then the recorded run
  queryperf -l 5 -s 10.0.0.2 < data/simple_data > data/direct.log

  sudo kill $serverpid
}

xen_direct () {
  compile xen

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
# unix_direct
# xen_direct
