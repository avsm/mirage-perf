#!/bin/bash -ex
# Performance tests for DNS

RANGE=$(cat RANGE)
SHORTRUN=2
LONGRUN=30
SERVERIP=$(cat SERVERIP)
CLIENTIP=$(cat CLIENTIP)
PASSWORD=$(cat PASSWORD)
SERVER="sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no root@$SERVERIP"
CLIENT="sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no root@$CLIENTIP"

if [ -z "$(which mir-unix-socket)" ]; then
  echo 'Add mirage tools to your path!'
  exit
fi

sudo echo 'Ensuring we have sudo credentials... done!'
ROOTDIR=$(pwd)

function nooffload {
   for i in rx tx sg tso ufo gso gro lro; do
     sudo ethtool -K $1 $i off || true
   done
}

# ensure perf0 bridge exists
bridge_reset () {
  sudo ifconfig perf0 down || true
  sudo brctl delbr perf0 || true
  sudo brctl addbr perf0
  sudo brctl setfd perf0 0
  sudo brctl sethello perf0 0
  sudo brctl stp perf0 off
  sudo ifconfig perf0 10.0.0.1 netmask 255.255.255.0
  sudo ifconfig perf0 up
  nooffload perf0
}
  
# deal with tool name change between versions
_SHV=/sys/hypervisor/version
XENV=$(cat ${_SHV}/major).$(cat ${_SHV}/minor)
[ "${XENV}" = "4.1" ] && XX=xl || XX=xm

bridge_reset
sudo ${XX} mem-set 0 1G
sudo ${XX} create $ROOTDIR/obj/xen-images/client.mirage-perf.local.cfg || true
sudo ${XX} create $ROOTDIR/obj/xen-images/server.mirage-perf.local.cfg || true

while true; do
  sleep 5  
  $SERVER "modprobe tun" && break
done

nooffload vif`sudo ${XX} domid client.mirage-perf.local`.0
nooffload vif`sudo ${XX} domid server.mirage-perf.local`.0

# oprofile options; for a pvops kernel, you need
# this kernel: http://github.com/avsm/linux-2.6.32-xen-oprofile
PROFILING=${PROFILING:-0}
# point to the xen symbol file
XEN_SYMS=/boot/xen-syms-4.1.0-rc7-pre

unix_socket () {
  $SERVER "./deens$1-socket.bin" &
  sleep 2
  
  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < queryperf-$1.txt" >| data/output-unix-socket-$1.txt

  $SERVER 'kill $(ps x | grep deens | grep -v grep | tr -s " " | cut -f 2 -d " ")'
}

unix_direct () {
  $SERVER "./deens$1-direct.bin" &
  sleep 2

  SERVERIP=10.0.0.10
  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < queryperf-$1.txt" >| data/output-unix-direct-$1.txt

  $SERVER 'kill $(ps x | grep deens | grep -v grep | tr -s " " | cut -f 2 -d " ")'
}

bind9 () {
  $SERVER "./bind9-install/sbin/named -c ./data/named-$1/named.conf-data" &
  sleep 2
  
  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < queryperf-$1.txt" >| data/output-bind9-unix-$1.txt

  $SERVER 'kill $(ps x | grep named | grep -v grep | tr -s " " | cut -f 2 -d " ")' || true
}

nsd3 () {

  zf=$(grep file ./data/named-$1/named.conf-data | cut -d '"' -f 2)
  z=$(grep zone ./data/named-$1/named.conf-data | cut -d'"' -f 2)
  
  $SERVER "./nsd-install/sbin/zonec -v -C -f ./data/nsd-$1.db -z $zf -o $z"
  $SERVER "./nsd-install/sbin/nsd -c ./nsd-install/etc/nsd/nsd-$1.conf -f ./data/nsd-$1.db" 

  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < queryperf-$1.txt" >| data/output-nsd-unix-$1.txt

  $SERVER 'kill $(ps x | grep nsd | grep -v grep | tr -s " " | cut -f 2 -d " ")'
}

for n in $RANGE ; do
  nsd3 $n
  bind9 $n
  unix_socket $n
  #  unix_direct $n
  echo .
done
sudo ${XX} destroy server.mirage-perf.local
sudo ${XX} destroy client.mirage-perf.local
sleep 5

xen_direct () {
  cd $ROOTDIR
  bridge_reset
  
  # spawn VMs
  sudo $XX create $ROOTDIR/obj/xen-images/client.mirage-perf.local.cfg
  sleep 3

  pushd app/
  sudo $XX create -p ../data/minios-$n.conf &
  popd
  
  sleep 2
  DOMNAME=deens$n
  DOMID=$(sudo $XX domid $DOMNAME)
  
  if [ ${PROFILING} -gt 0 ]; then
    sudo opcontrol --reset
    sudo opcontrol --shutdown
    sudo opcontrol --start-daemon --event=CPU_CLK_UNHALTED:1000000 --xen=${XEN_SYMS} \
      --passive-domains=${DOMID} --passive-images=${ROOTDIR}/app/${DOMNAME}.xen --no-vmlinux
    sudo opcontrol --start
  fi

  # queryperf tests
  sudo $XX unpause $DOMNAME
  sleep 1

  ping -c 3 $SERVERIP
  ping -c 3 $CLIENTIP

  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < queryperf-$1.txt" >| data/output-xen-direct-$1.txt

  if [ ${PROFILING} -gt 0 ]; then
    sudo opcontrol --stop
    opreport -l | grep domain${DOMID} > data/oprofile-raw-xen-direct-$1.txt
  fi

  # cleanup
  sleep 3
  sudo $XX destroy $DOMNAME
  sudo $XX destroy client.mirage-perf.local
  sleep 5
}

for n in $RANGE ; do
  xen_direct $n
done
