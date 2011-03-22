#!/bin/bash -ex
#
# mirage-perf DNS experiments: run experiments
#
# Anil Madhavapeddy <anil@recoil.org>
# Richard Mortier <mort@cantab.net>

sudo echo 'Ensuring we have sudo credentials... done!'

if [ -z "$(which mir-unix-socket)" ]; then
  echo 'Add mirage tools to your path!'
  exit
fi

ROOTDIR=$(cd $(dirname $0)/.. 2>/dev/null; pwd -P)
pushd $ROOTDIR

RANGE=$1
[ -z "$RANGE" ] && RANGE=$(cat ./cfg/RANGE)

EXPT=$2
[ -z "$EXPT" ] && EXPT=all

SHORTRUN=$(cat ./cfg/SHORTRUN)
LONGRUN=$(cat ./cfg/LONGRUN)

SERVERIP=$(cat ./cfg/SERVERIP)
CLIENTIP=$(cat ./cfg/CLIENTIP)
PASSWORD=$(cat ./cfg/PASSWORD)
SERVER="sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no root@$SERVERIP"
CLIENT="sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no root@$CLIENTIP"
  
# deal with tool name change between versions
_SHV=/sys/hypervisor/version
XENV=$(cat ${_SHV}/major).$(cat ${_SHV}/minor)
[ "${XENV}" = "4.1" ] && XX=xl || XX=xm

# oprofile options; for a pvops kernel, you need
# this kernel: http://github.com/avsm/linux-2.6.32-xen-oprofile
PROFILING=${PROFILING:-0}
# point to the xen symbol file
XEN_SYMS=/boot/xen-syms-4.1.0-rc7-pre

# ensure all card offload functions are turned off as mirage doesn't support them.
# yet.
nooffload () {
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

bridge_reset
sudo ${XX} mem-set 0 1G
sudo ${XX} create $ROOTDIR/obj/xen-images/client.mirage-perf.local.cfg || true
sudo ${XX} create $ROOTDIR/obj/xen-images/server.mirage-perf.local.cfg || true

while true; do
  sleep 5  
  $SERVER "modprobe tun" && break
done

nooffload vif$(sudo ${XX} domid client.mirage-perf.local).0
nooffload vif$(sudo ${XX} domid server.mirage-perf.local).0

for n in $RANGE ; do
  ( [ "$EXPT" == "nsd" ] || [ "$EXPT" == "all" ] ) && nsd3 $n || true
  ( [ "$EXPT" == "bind" ] || [ "$EXPT" == "all" ] ) && bind9 $n || true
  ( [ "$EXPT" == "unix-socket" ] || [ "$EXPT" == "all" ] ) && unix_socket $n || true
  ( [ "$EXPT" == "unix-direct" ] || [ "$EXPT" == "all" ] ) && unix_direct $n || true
  echo .
done

sudo ${XX} shutdown server.mirage-perf.local
sudo ${XX} shutdown client.mirage-perf.local
sleep 5

for n in $RANGE ; do
  ( [ "$EXPT" == "xen-direct" ] || [ "$EXPT" == "all" ] ) && xen_direct $n || true
done
