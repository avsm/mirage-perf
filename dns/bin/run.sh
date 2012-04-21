#!/bin/bash -ex
#
# mirage-perf DNS experiments: run experiments
#
# Anil Madhavapeddy <anil@recoil.org>
# Richard Mortier <mort@cantab.net>

sudo echo 'Ensuring we have sudo credentials... done!'

ROOTDIR=$(cd $(dirname $0)/.. 2>/dev/null; pwd -P)
cd $ROOTDIR

[ ! -d "$MIRDIR" ] && MIRDIR=$ROOTDIR/../../mirage
[ ! -d "$MIRDIR" ] && MIRDIR=$ROOTDIR/../../mirage.git
if [ ! -d "$MIRDIR" ] ; then
   echo "Please set MIRDIR to your mirage directory!"
   echo "Current value: MIRDIR=$MIRDIR"
   exit
fi

#if [ -z "$(which mir-unix-socket)" ]; then
#  echo 'Add mirage tools to your path!'
#  exit
#fi

RANGE=$1
[ -z "$RANGE" ] && RANGE=$(cat ./cfg/RANGE)

EXPT=$2
[ -z "$EXPT" ] && EXPT=all
echo EXPT=$EXPT

TAGS=$(cat ./cfg/TAGS)
[ -z "$TAGS" ] && TAGS=HEAD

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

# domU management utils
spawn_paused () {
  sudo $XX create -p $1 || true
  sleep 3
}

spawn () {
  sudo $XX create $1 || true
  sleep 3
}

shutdown () {
  sudo $XX shutdown $1 || true
  sleep 3
  sudo $XX destroy $1 || true
  sleep 3
}

destroy () {
  sleep 3
  sudo $XX destroy $1 || true
}

# ensure all card offload functions are turned off as mirage doesn't support them.
# yet.
nooffload () {
  for i in rx tx sg tso ufo gso gro lro; do
    sudo ethtool -K $1 $i off 2>/dev/null || true
  done
}

# ensure perf0 bridge exists
bridge_reset () {
  sudo ifconfig perf0 down || true
  sudo brctl delbr perf0 || true
  sudo brctl addbr perf0
  sudo brctl setfd perf0 0
  sudo brctl stp perf0 off
  sudo ifconfig perf0 10.0.0.1 netmask 255.255.255.0
  sudo ifconfig perf0 up
  nooffload perf0
}

bind9 () {
  ping -c 3 $SERVERIP
  $SERVER "./bind9-install/sbin/named -c ./data/named-$1/named.conf-data" &
  sleep 2
  
  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < data/queryperf-$1.txt" >| results-data/output-bind9-unix-$1.txt

  $SERVER 'kill $(ps x | grep named | grep -v grep | tr -s " " | cut -f 2 -d " ")' || true
}

nsd3 () {
  ping -c 3 $SERVERIP
  zf=$(grep file ./data/named-$1/named.conf-data | cut -d '"' -f 2)
  z=$(grep zone ./data/named-$1/named.conf-data | cut -d'"' -f 2)
  
  $SERVER "./nsd-install/sbin/zonec -v -C -f ./data/nsd-$1.db -z $zf -o $z"
  $SERVER "./nsd-install/sbin/nsd -c ./nsd-install/etc/nsd/nsd-$1.conf -f ./data/nsd-$1.db" 

  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < data/queryperf-$1.txt" >| results-data/output-nsd-unix-$1.txt

  $SERVER 'kill $(ps x | grep nsd | grep -v grep | tr -s " " | cut -f 2 -d " ")'
}

unix_socket () {
  ping -c 3 $SERVERIP
  $SERVER "(cd data/namedx-$1 && /root/data/crunch-$1/_build/unix-socket/crunchDNS.bin)" &
  sleep 2

  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < data/queryperf-$1.txt" >| $DATA/output-unix-socket-$1.txt

  $SERVER 'kill $(ps x | grep deens | grep -v grep | tr -s " " | cut -f 2 -d " ")'
}

unix_direct () {
  ping -c 3 $SERVERIP
  $SERVER "(cd data/namedx-$1 && /root/data/crunch-$1/_build/unix-direct/crunchDNS.bin)" &
  sleep 2

  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < data/queryperf-$1.txt" >| $DATA/output-unix-direct-$1.txt

  $SERVER 'kill $(ps x | grep deens | grep -v grep | tr -s " " | cut -f 2 -d " ")'
}

xen_direct () {
  cd $ROOTDIR
  bridge_reset
 
  # spawn VMs
  spawn $ROOTDIR/obj/xen-images/client.mirage-perf.local.cfg
  pushd app/_build
  spawn_paused ../../data/minios-$n.conf
  popd

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

  ping -c 5 $SERVERIP
  ping -c 5 $CLIENTIP

  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${SHORTRUN} -s ${SERVERIP} < data/queryperf-$1.txt"
  $CLIENT "./queryperf -l ${LONGRUN} -s ${SERVERIP} < data/queryperf-$1.txt" >| $DATA/output-xen-direct-$1.txt

  if [ ${PROFILING} -gt 0 ]; then
    sudo opcontrol --stop
    opreport -l | grep domain${DOMID} > $DATA/oprofile-raw-xen-direct-$1.txt
  fi

  # cleanup
  destroy $DOMNAME
  shutdown client.mirage-perf.local
}

checkout_and_build () {
  tag=$1

  pushd $MIRDIR
  git checkout $(git rev-parse $tag)
  make && make all install
  popd

  pushd $ROOTDIR/app
  rm -rf ./*.bin ./*.xen ./_build
  popd

  mkdir -p data/$tag
}

bridge_reset
sudo $XX mem-set 0 2G
spawn $ROOTDIR/obj/xen-images/client.mirage-perf.local.cfg
spawn $ROOTDIR/obj/xen-images/server.mirage-perf.local.cfg
$SERVER "modprobe tun" 

nooffload vif$(sudo $XX domid client.mirage-perf.local).0
nooffload vif$(sudo $XX domid server.mirage-perf.local).0

for n in $RANGE ; do
  echo "=== NSD/BIND === $n ==="
  ( [ "$EXPT" == "nsd" ] || [ "$EXPT" == "all" ] ) && nsd3 $n || true
  ( [ "$EXPT" == "bind" ] || [ "$EXPT" == "all" ] ) && bind9 $n || true
done

for t in $TAGS ; do
  shutdown server.mirage-perf.local
#  checkout_and_build $t
           
  DATA=results-data/$t
  mkdir -p $DATA

  #pushd app
  #mir-build unix-socket/deensOpenmirage.bin
  #popd

  cd $ROOTDIR
#  sudo mount -o loop ./obj/xen-images/domains/server.mirage-perf.local/disk.img ./m
#  sudo cp -vr data ./m/root/input/
#  sudo umount ./m
  spawn $ROOTDIR/obj/xen-images/server.mirage-perf.local.cfg
  for n in $RANGE ; do
    echo "=== MIR/UNIX === $n === $t ==="
    ( [ "$EXPT" == "unix-socket" ] || [ "$EXPT" == "all" ] ) && unix_socket $n || true
##    ( [ "$EXPT" == "unix-direct" ] || [ "$EXPT" == "all" ] ) && unix_direct $n || true
  done
  shutdown server.mirage-perf.local
  shutdown client.mirage-perf.local

  for n in $RANGE ; do
    echo "=== MIR/XEN === $n === $t ==="
    ( [ "$EXPT" == "xen-direct" ] || [ "$EXPT" == "all" ] ) && xen_direct $n || true
  done
done
