#!/bin/bash -ex
# Performance tests for DNS

if [ -z "$(which mir-unix-socket)" ]; then
  echo 'Add mirage tools to your path!'
  exit
fi

sudo echo 'Ensuring we have sudo credentials... done!'
ROOTDIR=$(pwd)

# deal with tool name change between versions
_SHV=/sys/hypervisor/version
XENV=$(cat ${_SHV}/major).$(cat ${_SHV}/minor)
[ "${XENV}" = "4.1" ] && XX=xl || XX=xm

RANGE=$(cat RANGE)
SHORTRUN=2
LONGRUN=30
DEENSIP=0.0.0.0

compile () {
  pushd $ROOTDIR/app
  [ "$1" = "xen" ] && mir-$1 deens$2.xen || mir-$1 deens$2.bin
  popd
}

perform () {
  pushd $ROOTDIR
  queryperf -l ${SHORTRUN} -s ${DEENSIP} < $1 
  queryperf -l ${LONGRUN} -s ${DEENSIP} < $1 > $2
  popd
}

unix_socket () {
  cd $ROOTDIR
  compile unix-socket $1
  
  sudo ./app/_build/deens$1.bin &
  sleep 2
  serverpid=$!

  DEENSIP=127.0.0.1
  perform data/queryperf-$1.txt data/output-unix-socket-$1.txt
  
  sudo kill $serverpid || true
}

unix_direct () {
  cd $ROOTDIR
  sudo modprobe tun
  compile unix-direct $1

  sudo ./app/_build/deens$1.bin &
  sleep 2
  serverpid=$!

  DEENSIP=10.0.0.2
  perform data/queryperf-$1.txt data/output-unix-direct-$1.txt

  sudo kill $serverpid || true
}

xen_direct () {
  cd $ROOTDIR
  compile xen $1

  sudo brctl addbr perf0 || true
  sudo brctl setfd perf0 0
  sudo brctl sethello perf0 0
  sudo brctl stp perf0 off
  sudo ifconfig perf0 10.0.0.1 netmask 255.255.255.0
  sudo ifconfig perf0 up

  # spawn VM
  pushd app/_build
  cp $ROOTDIR/minios-$n.conf .
  sudo $XX create minios-$n.conf &
  popd
  
  sleep 5
  DEENSIP=10.0.0.2
  ping -c 3 ${DEENSIP}

  perform data/queryperf-$1.txt data/output-xen-direct-$1.txt
  sleep 3
  sudo $XX destroy deens$1
  sudo ifconfig perf0 down
  sudo brctl delbr perf0
  
  #  sudo $XX console deens
}

nsd3 () {
  killall nsd
  cd $ROOTDIR
  
  db=${ROOTDIR}/data/nsd-${n}.db
  zd=${ROOTDIR}/data/named-${n}
  zf=${ROOTDIR}/$(grep file ${zd}/named.conf-data | cut -d '"' -f 2)
  z=$(grep zone ${zd}/named.conf-data | cut -d'"' -f 2)

  pushd obj/nsd-install
  sudo ./sbin/nsd -c ./etc/nsd/nsd-$n.conf -f $db -P ./var/db/nsd/nsd.pid
  serverpid=$(cat ${ROOTDIR}/obj/nsd-install/var/db/nsd/nsd.pid)
  popd

  perform data/queryperf-$1.txt data/output-nsd-unix-$1.txt

  sudo kill $serverpid || true
}

for n in $RANGE ; do
  unix_socket $n
  unix_direct $n
  xen_direct $n
  nsd3 $n
done

