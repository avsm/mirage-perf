#!/usr/bin/env bash
set -ex

RANGE=$(cat cfg/RANGE)
CLIENT="sshpass -fcfg/PASSWORD ssh root@simba-2.xeno.cl.cam.ac.uk"

rsync -av --rsh="sshpass -fcfg/PASSWORD ssh -l root" ../../mirage-perf simba-2.xeno.cl.cam.ac.uk:

for i in $RANGE; do
  echo $i
  sudo xl destroy crunchDNS.xen || true
  mir-run -b xen -m 512 -vif loopbr0 ./data/crunch-$i/_build/xen/crunchDNS.xen &
  sleep 5
  $CLIENT ping -c 5 10.0.0.2
  $CLIENT "(cd mirage-perf/dns; ./queryperf -l 30 -s 10.0.0.2 < data/queryperf-$i.txt)" > data/output-xen-$i.txt
done
