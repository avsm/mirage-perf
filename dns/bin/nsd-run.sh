#!/usr/bin/env bash
set -ex

RANGE=$(cat cfg/RANGE)
CLIENT="sshpass -fcfg/PASSWORD ssh root@simba-2.xeno.cl.cam.ac.uk"
SERVER="sshpass -fcfg/PASSWORD ssh root@simba-1.xeno.cl.cam.ac.uk"

rsync -av --rsh="sshpass -fcfg/PASSWORD ssh -l root" obj data simba-1.xeno.cl.cam.ac.uk:

for i in $RANGE; do
  $SERVER "./obj/nsd-install/sbin/nsd -c ./obj/nsd-install/etc/nsd/nsd-$i.conf -f ./data/nsd-$i.db"
  sleep 5
  $CLIENT "(cd mirage-perf/dns; ./queryperf -l 30 -s 10.0.0.3 < data/queryperf-$i.txt)" > data/output-nsd-$i.txt
  $SERVER killall nsd
done
