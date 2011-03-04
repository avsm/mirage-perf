#!/bin/sh

RANGE="1 10 100 1000 10000"
for n in $RANGE ; do
  for f in rawdata.conf format.conf ; do
    rm -f -- "$f-$n"
    sed "s/@NHOSTS@/$n/g" $f > $f-$n
  done
  for f in rawdata-$n.conf ; do
    rm -f -- "raw-$n.csv"
    ../dlz-perf-tools/dnsDataGen.pl $f
  done
  for f in format-$n.conf ; do
    rm -rf -- "named-$n/"
    mkdir named-$n
    ../dlz-perf-tools/dnsCSVDataReader.pl $f
  done
done

