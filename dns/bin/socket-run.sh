#!/usr/bin/env bash
set -ex

RANGE=$(cat cfg/RANGE)
CLIENT="sshpass -fcfg/PASSWORD ssh root@simba-2.xeno.cl.cam.ac.uk"
SERVER="sshpass -fcfg/PASSWORD ssh root@simba-1.xeno.cl.cam.ac.uk"

rsync -av --rsh="sshpass -fcfg/PASSWORD ssh -l root" data simba-1.xeno.cl.cam.ac.uk:

for i in $RANGE; do
  $SERVER data/crunch-$i/_build/unix-socket/crunchDNS.bin &
  sleep 5
  $CLIENT "(cd mirage-perf/dns; ./queryperf -l 30 -s 10.0.0.3 < data/queryperf-$i.txt)" > data/output-unix-socket-$i.txt
  $SERVER killall crunchDNS.bin
done
