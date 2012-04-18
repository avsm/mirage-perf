#!/usr/bin/env bash
set -ex

RANGE=$(cat cfg/RANGE)
RANGE=10
CLIENT="sshpass -fcfg/PASSWORD ssh root@simba-2.xeno.cl.cam.ac.uk"
SERVER="sshpass -fcfg/PASSWORD ssh root@simba-1.xeno.cl.cam.ac.uk"

rsync -av --rsh="sshpass -fcfg/PASSWORD ssh -l root" obj data simba-1.xeno.cl.cam.ac.uk:

for i in $RANGE; do
  $SERVER "./obj/bind9-install/sbin/named -c ./data/named-$i/named.conf-data"
  sleep 8
  $CLIENT "(cd mirage-perf/dns; ./queryperf -l 10 -s 10.0.0.3 < data/queryperf-$i.txt)" > data/output-bind9-$i.txt
  $SERVER killall named
done
